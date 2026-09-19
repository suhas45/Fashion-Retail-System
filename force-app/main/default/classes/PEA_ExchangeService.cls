/**
 * Shared business logic, @InvocableVariable request/response types, and
 * agent-facing data types for the Product Exchange Assistant agent's three
 * actions (PEA_GetOrderLines, PEA_CheckSkuAvailability, PEA_CreateExchange).
 * Not itself an invocable action - Salesforce allows only one
 * @InvocableMethod per class, so each action is a thin wrapper class that
 * delegates here. Declared global (with global nested types below) because
 * PEA_OrderLine/PEA_OrderLinesResult are referenced from Agent Script via
 * complex_data_type_name, which requires global visibility.
 */
global without sharing class PEA_ExchangeService {
    // ---- Get Order Lines ----
    // Agent action data type: a single order line item.
    @JsonAccess(serializable='always' deserializable='always')
    global class PEA_OrderLine {
        @AuraEnabled global String orderLineId;
        @AuraEnabled global String orderLineName;
        @AuraEnabled global String orderNumber;
        @AuraEnabled global String orderStatus;
        @AuraEnabled global Date orderDate;
        @AuraEnabled global String skuId;
        @AuraEnabled global String skuName;
        @AuraEnabled global String color;
        @AuraEnabled global String size;
        @AuraEnabled global String productId;
        @AuraEnabled global String productName;
        @AuraEnabled global String productImageUrl;
        @AuraEnabled global Decimal quantity;
        @AuraEnabled global Decimal price;
    }
    // Agent action data type: aggregate result of PEA_GetOrderLines - the
    // resolved customer identity (Contact/Account, when authenticated)
    // plus their matching orders and line items.
    @JsonAccess(serializable='always' deserializable='always')
    global class PEA_OrderLinesResult {
        @AuraEnabled global Boolean found;
        @AuraEnabled global String contactId;
        @AuraEnabled global String contactName;
        @AuraEnabled global String accountId;
        @AuraEnabled global String accountName;
        @AuraEnabled global Integer totalFound;
        @AuraEnabled global String primaryOrderLineId;
        @AuraEnabled global String primarySkuId;
        @AuraEnabled global String primaryProductName;
        @AuraEnabled global List<PEA_OrderLine> lines;
    }
    public class GetOrderLinesRequest {
        @InvocableVariable(
            label='Contact Id'
            description='Contact Id of the authenticated messaging end user. Preferred identity input for Experience Cloud/Enhanced Chat v2.'
        )
        public String contactId;
        @InvocableVariable(
            label='Authenticated User Id'
            description='Optional fallback Salesforce User Id. Contact Id is preferred for authenticated messaging users.'
        )
        public String authenticatedUserId;
        @InvocableVariable(
            label='Order Number'
            description='Order number the customer provided, if any. When contactId and authenticatedUserId are blank, this is the only way to identify which order to look up.'
        )
        public String orderNumber;
    }
    public class GetOrderLinesResponse {
        @InvocableVariable(label='Response' description='Resolved customer identity (contact/account) plus matching orders and line items')
        public PEA_OrderLinesResult response;
    }
    // Either authenticatedUserId or orderNumber must be supplied per
    // request. When authenticatedUserId is present, results are scoped
    // strictly to that customer's Account (orderNumber, if also given,
    // narrows further). When authenticatedUserId is blank (e.g. testing in
    // Agent Builder), orderNumber alone is the identifier - it is private
    // information only the customer would know.
    public static List<GetOrderLinesResponse> getOrderLines(List<GetOrderLinesRequest> inputs) {
        List<GetOrderLinesResponse> responses = new List<GetOrderLinesResponse>();
        for (GetOrderLinesRequest req : inputs) {
            System.debug(LoggingLevel.ERROR, '[PEA DEBUG] contactId=' + req.contactId
                + ' authenticatedUserId=' + req.authenticatedUserId
                + ' orderNumber=' + req.orderNumber);
            PEA_OrderLinesResult result = new PEA_OrderLinesResult();
            result.lines = new List<PEA_OrderLine>();
            if (String.isBlank(req.contactId) && String.isBlank(req.authenticatedUserId) && String.isBlank(req.orderNumber)) {
                System.debug(LoggingLevel.ERROR, '[PEA DEBUG] ContactId, authenticatedUserId, and orderNumber are all blank.');
                result.found = false;
                responses.add(wrapOrderLines(result));
                continue;
            }
            List<Order> orders;
            if (String.isNotBlank(req.contactId) || String.isNotBlank(req.authenticatedUserId)) {
                Identity identity;
                if (String.isNotBlank(req.contactId)) {
                    System.debug(LoggingLevel.ERROR, '[PEA DEBUG] Resolving identity directly from ContactId=' + req.contactId);
                    identity = resolveIdentityByContact(req.contactId);
                } else {
                    System.debug(LoggingLevel.ERROR, '[PEA DEBUG] ContactId blank; using authenticatedUserId fallback=' + req.authenticatedUserId);
                    identity = resolveIdentity(req.authenticatedUserId);
                }
                System.debug(LoggingLevel.ERROR, '[PEA DEBUG] Identity result=' + JSON.serialize(identity));
                if (identity == null) {
                    System.debug(LoggingLevel.ERROR, '[PEA DEBUG] Could not resolve Contact/Account identity.');
                    result.found = false;
                    responses.add(wrapOrderLines(result));
                    continue;
                }
                System.debug(LoggingLevel.ERROR, '[PEA DEBUG] Resolved identity: contactId=' + identity.contactId
                    + ' contactName=' + identity.contactName
                    + ' accountId=' + identity.accountId
                    + ' accountName=' + identity.accountName);
                result.contactId = identity.contactId;
                result.contactName = identity.contactName;
                result.accountId = identity.accountId;
                result.accountName = identity.accountName;
                orders = String.isNotBlank(req.orderNumber) ? [
                    SELECT Id, OrderNumber, Status, EffectiveDate
                    FROM Order
                    WHERE AccountId = :identity.accountId AND OrderNumber = :req.orderNumber
                    ORDER BY EffectiveDate DESC
                    LIMIT 5
                ] : [
                    SELECT Id, OrderNumber, Status, EffectiveDate
                    FROM Order
                    WHERE AccountId = :identity.accountId
                    ORDER BY EffectiveDate DESC
                    LIMIT 5
                ];
            } else {
                orders = [
                    SELECT Id, OrderNumber, Status, EffectiveDate
                    FROM Order
                    WHERE OrderNumber = :req.orderNumber
                    LIMIT 5
                ];
            }
            List<String> orderNumbersFound = new List<String>();
            for (Order ord : orders) {
                orderNumbersFound.add(ord.OrderNumber);
            }
            System.debug(LoggingLevel.ERROR, '[PEA DEBUG] Found ' + orders.size() + ' order(s): ' + orderNumbersFound);
            if (orders.isEmpty()) {
                result.found = false;
                responses.add(wrapOrderLines(result));
                continue;
            }
            result.found = true;
            Map<Id, Order> ordersById = new Map<Id, Order>(orders);
            // Order_Line__c is a custom object with no automatic portal-
            // user sharing visibility, so this runs without WITH USER_MODE;
            // the parent Order is already scoped to the resolved Account
            // above. Order_Line__c has no price field of its own - price
            // comes from the SKU's current catalog price (SKU__r.Price__c).
            // Ordered by the parent order's start date (EffectiveDate) so
            // lines arrive pre-grouped by order, most recent order first.
            List<Order_Line__c> items = [
                SELECT Id, Name, Order__c, Quantity__c,
                    SKU__c, SKU__r.Name, SKU__r.Color__c, SKU__r.Size__c, SKU__r.Price__c,
                    SKU__r.Product__c, SKU__r.Product__r.Name, SKU__r.Product__r.Product_Image__c
                FROM Order_Line__c
                WHERE Order__c IN :ordersById.keySet()
                ORDER BY Order__r.EffectiveDate DESC, CreatedDate ASC
            ];
            for (Order_Line__c oi : items) {
                Order ord = ordersById.get(oi.Order__c);
                PEA_OrderLine line = new PEA_OrderLine();
                line.orderLineId = oi.Id;
                line.orderLineName = oi.Name;
                line.orderNumber = ord.OrderNumber;
                line.orderStatus = ord.Status;
                line.orderDate = ord.EffectiveDate;
                line.skuId = oi.SKU__c;
                line.skuName = oi.SKU__r != null ? oi.SKU__r.Name : null;
                line.color = oi.SKU__r != null ? oi.SKU__r.Color__c : null;
                line.size = oi.SKU__r != null ? oi.SKU__r.Size__c : null;
                line.productId = oi.SKU__r != null ? oi.SKU__r.Product__c : null;
                line.productName = oi.SKU__r != null && oi.SKU__r.Product__r != null ? oi.SKU__r.Product__r.Name : null;
                line.productImageUrl = oi.SKU__r != null && oi.SKU__r.Product__r != null
                    ? extractImageUrl(oi.SKU__r.Product__r.Product_Image__c)
                    : null;
                line.quantity = oi.Quantity__c;
                line.price = oi.SKU__r != null ? parsePrice(oi.SKU__r.Price__c) : null;
                result.lines.add(line);
            }
            result.totalFound = result.lines.size();
            if (result.totalFound == 1) {
                PEA_OrderLine only = result.lines[0];
                result.primaryOrderLineId = only.orderLineId;
                result.primarySkuId = only.skuId;
                result.primaryProductName = only.productName;
            }
            System.debug(LoggingLevel.ERROR, '[PEA DEBUG] FINAL RESULT=' + JSON.serialize(result));
            responses.add(wrapOrderLines(result));
        }
        return responses;
    }
    private static GetOrderLinesResponse wrapOrderLines(PEA_OrderLinesResult result) {
        GetOrderLinesResponse res = new GetOrderLinesResponse();
        res.response = result;
        return res;
    }
    // ---- Check SKU Availability ----
    @JsonAccess(serializable='always' deserializable='always')
    global class CheckAvailabilityInput {
        @InvocableVariable(label='Desired Size' description='Size the customer wants instead' required=true)
        @AuraEnabled global String desiredSize;
        @InvocableVariable(label='Desired Color' description='Color the customer wants instead; leave blank to keep the current color')
        @AuraEnabled global String desiredColor;
    }
    public class CheckAvailabilityRequest {
        public String currentSkuId;
        public String desiredSize;
        public String desiredColor;
    }
    @JsonAccess(serializable='always' deserializable='always')
    global class AvailableOption {
        @AuraEnabled global String skuId;
        @AuraEnabled global String size;
        @AuraEnabled global String color;
        @AuraEnabled global Decimal price;
    }
    @JsonAccess(serializable='always' deserializable='always')
    global class CheckAvailabilityResponse {
        @InvocableVariable(label='Is Available' description='Whether the requested size/color is currently in stock')
        @AuraEnabled global Boolean isAvailable = false;
        @InvocableVariable(label='Resolved SKU Id' description='Id of the SKU matching product+size+color, when available')
        @AuraEnabled global String resolvedSkuId;
        @InvocableVariable(label='Resolved SKU Name' description='Name of the resolved SKU')
        @AuraEnabled global String resolvedSkuName;
        @InvocableVariable(label='Current SKU Price' description='Price of the SKU currently owned, when known')
        @AuraEnabled global Decimal currentSkuPrice;
        @InvocableVariable(label='New SKU Price' description='Price of the resolved SKU, when known')
        @AuraEnabled global Decimal newSkuPrice;
        @InvocableVariable(label='Price Difference' description='New SKU price minus current SKU price. Positive = customer owes the difference, negative = refund owed, zero = no additional charge.')
        @AuraEnabled global Decimal priceDifference;
        @InvocableVariable(label='Available Options Text' description='Plain-text size/color combinations of this product currently in stock, when the requested one is not available')
        @AuraEnabled global String availableOptionsText;
        @InvocableVariable(label='Available Options' description='Structured list of all in-stock size/color SKU options for the product')
        @AuraEnabled global List<AvailableOption> options;
    }
    public static List<CheckAvailabilityResponse> checkAvailability(List<CheckAvailabilityRequest> inputs) {
        List<CheckAvailabilityResponse> responses = new List<CheckAvailabilityResponse>();
        for (CheckAvailabilityRequest req : inputs) {
            CheckAvailabilityResponse res = new CheckAvailabilityResponse();
            res.options = new List<AvailableOption>();
            if (String.isBlank(req.currentSkuId) || String.isBlank(req.desiredSize)) {
                res.isAvailable = false;
                responses.add(res);
                continue;
            }
            List<SKU__c> currentSkus = [
                SELECT Id, Product__c, Color__c, Price__c
                FROM SKU__c
                WHERE Id = :req.currentSkuId
                LIMIT 1
            ];
            if (currentSkus.isEmpty()) {
                res.isAvailable = false;
                responses.add(res);
                continue;
            }
            SKU__c currentSku = currentSkus[0];
            String targetColor = String.isNotBlank(req.desiredColor) ? req.desiredColor : currentSku.Color__c;
            res.currentSkuPrice = parsePrice(currentSku.Price__c);
            List<SKU__c> matches = [
                SELECT Id, Name, Size__c, Color__c, Price__c
                FROM SKU__c
                WHERE Product__c = :currentSku.Product__c
                    AND Size__c = :req.desiredSize
                    AND Color__c = :targetColor
                LIMIT 1
            ];
            Decimal qty = 0;
            if (!matches.isEmpty()) {
                List<SKU_Inventory__c> invRows = [
                    SELECT Quantity_On_Hand__c
                    FROM SKU_Inventory__c
                    WHERE SKU__c = :matches[0].Id
                    ORDER BY Quantity_On_Hand__c DESC
                    LIMIT 1
                ];
                if (!invRows.isEmpty()) {
                    qty = invRows[0].Quantity_On_Hand__c;
                }
            }
            if (!matches.isEmpty() && qty > 0) {
                SKU__c matchedSku = matches[0];
                res.resolvedSkuId = matchedSku.Id;
                res.resolvedSkuName = matchedSku.Name;
                res.isAvailable = true;
                res.newSkuPrice = parsePrice(matchedSku.Price__c);
                if (res.currentSkuPrice != null && res.newSkuPrice != null) {
                    res.priceDifference = res.newSkuPrice - res.currentSkuPrice;
                }
            } else {
                res.isAvailable = false;
                res.options = findStructuredAvailableOptions(currentSku.Product__c, currentSku.Id);
                res.availableOptionsText = formatStructuredAvailableOptions(res.options);
            }
            responses.add(res);
        }
        return responses;
    }
    private static List<AvailableOption> findStructuredAvailableOptions(Id productId, Id excludeSkuId) {
        List<AvailableOption> options = new List<AvailableOption>();
        List<AggregateResult> stocked = [
            SELECT SKU__c, SUM(Quantity_On_Hand__c) totalQuantity
            FROM SKU_Inventory__c
            WHERE SKU__r.Product__c = :productId
            GROUP BY SKU__c
            HAVING SUM(Quantity_On_Hand__c) > 0
        ];
        if (stocked.isEmpty()) {
            return options;
        }
        Set<Id> stockedSkuIds = new Set<Id>();
        for (AggregateResult ar : stocked) {
            Id skuId = (Id) ar.get('SKU__c');
            if (skuId != null && skuId != excludeSkuId) {
                stockedSkuIds.add(skuId);
            }
        }
        if (stockedSkuIds.isEmpty()) {
            return options;
        }
        List<SKU__c> skus = [
            SELECT Id, Name, Size__c, Color__c, Price__c
            FROM SKU__c
            WHERE Id IN :stockedSkuIds
            ORDER BY Color__c, Size__c
        ];
        for (SKU__c sku : skus) {
            AvailableOption option = new AvailableOption();
            option.skuId = sku.Id;
            option.size = sku.Size__c;
            option.color = sku.Color__c;
            option.price = parsePrice(sku.Price__c);
            options.add(option);
        }
        return options;
    }
    private static String formatStructuredAvailableOptions(List<AvailableOption> options) {
        List<String> labels = new List<String>();
        for (AvailableOption option : options) {
            String label = '';
            if (String.isNotBlank(option.size)) {
                label += option.size;
            }
            if (String.isNotBlank(option.color)) {
                if (String.isNotBlank(label)) {
                    label += ' / ';
                }
                label += option.color;
            }
            if (String.isNotBlank(label)) {
                labels.add(label);
            }
        }
        return String.join(labels, ', ');
    }
    // ---- Create Exchange ----
    public class CreateExchangeRequest {
        @InvocableVariable(
            label='Contact Id'
            description='Contact Id of the authenticated messaging end user. Preferred identity input for ownership validation.'
        )
        public String contactId;
        @InvocableVariable(
            label='Authenticated User Id'
            description='Optional fallback Salesforce User Id for ownership validation.'
        )
        public String authenticatedUserId;
        @InvocableVariable(label='Order Line Id' description='Id of the Order_Line__c being exchanged' required=true)
        public String orderLineId;
        @InvocableVariable(label='New SKU Id' description='Id of the new SKU to exchange into' required=true)
        public String newSkuId;
    }
    @JsonAccess(serializable='always' deserializable='always')
global class CreateExchangeResponse {
    @InvocableVariable(
        label='Success'
        description='Whether the exchange was created successfully'
    )
    @AuraEnabled
    global Boolean success = false;

    @InvocableVariable(
        label='Exchange Number'
        description='Confirmation number for the exchange'
    )
    @AuraEnabled
    global String exchangeNumber;

    @InvocableVariable(
        label='Status'
        description='Exchange status after creation'
    )
    @AuraEnabled
    global String status;

    @InvocableVariable(
        label='Order Number'
        description='Order number associated with the exchange'
    )
    @AuraEnabled
    global String orderNumber;

    @InvocableVariable(
        label='Order Line Id'
        description='Original order line being exchanged'
    )
    @AuraEnabled
    global String orderLineId;

    @InvocableVariable(
        label='Original SKU Id'
        description='SKU originally purchased'
    )
    @AuraEnabled
    global String originalSkuId;

    @InvocableVariable(
        label='Original SKU Name'
        description='Name of the originally purchased SKU'
    )
    @AuraEnabled
    global String originalSkuName;

    @InvocableVariable(
        label='Original Size'
        description='Size originally purchased'
    )
    @AuraEnabled
    global String originalSize;

    @InvocableVariable(
        label='Original Color'
        description='Color originally purchased'
    )
    @AuraEnabled
    global String originalColor;

    @InvocableVariable(
        label='New SKU Id'
        description='SKU selected for the exchange'
    )
    @AuraEnabled
    global String newSkuId;

    @InvocableVariable(
        label='New SKU Name'
        description='Name of the SKU selected for the exchange'
    )
    @AuraEnabled
    global String newSkuName;

    @InvocableVariable(
        label='New Size'
        description='Size selected for the exchange'
    )
    @AuraEnabled
    global String newSize;

    @InvocableVariable(
        label='New Color'
        description='Color selected for the exchange'
    )
    @AuraEnabled
    global String newColor;

    @InvocableVariable(
        label='Original Price'
        description='Price of the original SKU'
    )
    @AuraEnabled
    global Decimal originalPrice;

    @InvocableVariable(
        label='New Price'
        description='Price of the new SKU'
    )
    @AuraEnabled
    global Decimal newPrice;

    @InvocableVariable(
        label='Price Difference'
        description='Price difference returned by the exchange process'
    )
    @AuraEnabled
    global Decimal priceDifference;
}
    // orderLineId ownership is verified against the resolved Account when
    // authenticatedUserId is present, so one customer can never exchange
    // another's order line even if an orderLineId is supplied out of turn.
    public static List<CreateExchangeResponse> createExchange(
    List<CreateExchangeRequest> inputs
) {
    List<CreateExchangeResponse> responses =
        new List<CreateExchangeResponse>();

    for (CreateExchangeRequest req : inputs) {
        CreateExchangeResponse res =
            new CreateExchangeResponse();

        if (
            String.isBlank(req.orderLineId) ||
            String.isBlank(req.newSkuId)
        ) {
            res.status = 'Failed';
            responses.add(res);
            continue;
        }

        List<Order_Line__c> items = [
            SELECT
                Id,
                Order__c,
                SKU__c,
                SKU__r.Name,
                SKU__r.Size__c,
                SKU__r.Color__c,
                SKU__r.Price__c
            FROM Order_Line__c
            WHERE Id = :req.orderLineId
            LIMIT 1
        ];

        if (items.isEmpty()) {
            res.status = 'Failed';
            responses.add(res);
            continue;
        }

        Order_Line__c originalItem = items[0];

        if (
            String.isNotBlank(req.contactId) ||
            String.isNotBlank(req.authenticatedUserId)
        ) {
            Identity identity;

            if (String.isNotBlank(req.contactId)) {
                identity =
                    resolveIdentityByContact(req.contactId);
            } else {
                identity =
                    resolveIdentity(req.authenticatedUserId);
            }

            if (identity == null) {
                res.status = 'Failed';
                responses.add(res);
                continue;
            }

            List<Order> orders = [
                SELECT Id, AccountId, OrderNumber
                FROM Order
                WHERE Id = :originalItem.Order__c
                LIMIT 1
            ];

            if (
                orders.isEmpty() ||
                orders[0].AccountId != identity.accountId
            ) {
                res.status = 'Failed';
                responses.add(res);
                continue;
            }

            res.orderNumber = orders[0].OrderNumber;
        } else {
            List<Order> orders = [
                SELECT Id, OrderNumber
                FROM Order
                WHERE Id = :originalItem.Order__c
                LIMIT 1
            ];

            if (!orders.isEmpty()) {
                res.orderNumber = orders[0].OrderNumber;
            }
        }

        List<SKU__c> newSkus = [
            SELECT
                Id,
                Name,
                Size__c,
                Color__c,
                Price__c
            FROM SKU__c
            WHERE Id = :req.newSkuId
            LIMIT 1
        ];

        if (newSkus.isEmpty()) {
            res.status = 'Failed';
            responses.add(res);
            continue;
        }

        SKU__c newSku = newSkus[0];

        Exchange__c exchange = new Exchange__c(
            Order__c = originalItem.Order__c,
            Order_Item__c = originalItem.Id,
            Original_SKU__c = originalItem.SKU__c,
            New_SKU__c = newSku.Id,
            Status__c = 'Requested'
        );

        insert exchange;

        Exchange__c saved = [
            SELECT Name
            FROM Exchange__c
            WHERE Id = :exchange.Id
            LIMIT 1
        ];

        res.success = true;
        res.exchangeNumber = saved.Name;
        res.status = 'Requested';

        res.orderLineId = originalItem.Id;

        res.originalSkuId =
            originalItem.SKU__c;

        res.originalSkuName =
            originalItem.SKU__r != null
                ? originalItem.SKU__r.Name
                : null;

        res.originalSize =
            originalItem.SKU__r != null
                ? originalItem.SKU__r.Size__c
                : null;

        res.originalColor =
            originalItem.SKU__r != null
                ? originalItem.SKU__r.Color__c
                : null;

        res.newSkuId =
            newSku.Id;

        res.newSkuName =
            newSku.Name;

        res.newSize =
            newSku.Size__c;

        res.newColor =
            newSku.Color__c;

        res.originalPrice =
            parsePrice(
                originalItem.SKU__r != null
                    ? originalItem.SKU__r.Price__c
                    : null
            );

        res.newPrice =
            parsePrice(newSku.Price__c);

        if (
            res.originalPrice != null &&
            res.newPrice != null
        ) {
            res.priceDifference =
                res.newPrice - res.originalPrice;
        }

        responses.add(res);
    }

    return responses;
}
    // ---- Shared helpers ----
    private class Identity {
        Id contactId;
        String contactName;
        Id accountId;
        String accountName;
    }
    // Resolves the messaging session's authenticated Salesforce User to
    // their Contact/Account. The User lookup runs without WITH USER_MODE
    // deliberately: the Id was asserted by Salesforce's own authenticated-
    // messaging platform (not customer input), and the agent's restricted
    // running-user license does not support viewing other User records
    // via normal CRUD/FLS.
    private static Identity resolveIdentityByContact(String contactId) {
        if (String.isBlank(contactId)) {
            return null;
        }
        List<Contact> contacts = [
            SELECT Id, AccountId, FirstName, LastName, Account.Name
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];
        System.debug(LoggingLevel.ERROR, '[PEA DEBUG] Contact lookup count=' + contacts.size());
        if (contacts.isEmpty() || contacts[0].AccountId == null) {
            return null;
        }
        Contact c = contacts[0];
        Identity identity = new Identity();
        identity.contactId = c.Id;
        identity.contactName = String.isNotBlank(c.FirstName) ? c.FirstName + ' ' + c.LastName : c.LastName;
        identity.accountId = c.AccountId;
        identity.accountName = c.Account != null ? c.Account.Name : null;
        System.debug(LoggingLevel.ERROR, '[PEA DEBUG] Contact resolved: ContactId=' + c.Id + ' AccountId=' + c.AccountId + ' AccountName=' + identity.accountName);
        return identity;
    }
    private static Identity resolveIdentity(String authenticatedUserId) {
        List<User> users = [
            SELECT ContactId FROM User WHERE Id = :authenticatedUserId LIMIT 1
        ];
        if (users.isEmpty() || users[0].ContactId == null) {
            return null;
        }
        List<Contact> contacts = [
            SELECT Id, AccountId, FirstName, LastName, Account.Name
            FROM Contact
            WHERE Id = :users[0].ContactId
            LIMIT 1
        ];
        if (contacts.isEmpty() || contacts[0].AccountId == null) {
            return null;
        }
        Contact c = contacts[0];
        Identity identity = new Identity();
        identity.contactId = c.Id;
        identity.contactName = String.isNotBlank(c.FirstName) ? c.FirstName + ' ' + c.LastName : c.LastName;
        identity.accountId = c.AccountId;
        identity.accountName = c.Account != null ? c.Account.Name : null;
        return identity;
    }
    // SKU Price__c is a plain Text field (e.g. "$99.00"), not Currency, so
    // it has to be parsed rather than read as a Decimal directly.
    private static Decimal parsePrice(String rawPrice) {
        if (String.isBlank(rawPrice)) {
            return null;
        }
        String cleaned = rawPrice.replaceAll('[^0-9.\\-]', '');
        if (String.isBlank(cleaned)) {
            return null;
        }
        try {
            return Decimal.valueOf(cleaned).setScale(2);
        } catch (Exception e) {
            return null;
        }
    }
    // Product_Image__c is a rich text (Html) field that typically holds an
    // <img> tag (e.g. from a data import), rather than a plain URL, so the
    // src has to be pulled out for use in a plain <img> element. Falls back
    // to the raw value when it's already a bare URL.
    private static final Pattern IMG_SRC_PATTERN = Pattern.compile('(?i)src\\s*=\\s*"([^"]+)"');
    private static String extractImageUrl(String rawHtml) {
        if (String.isBlank(rawHtml)) {
            return null;
        }
        Matcher m = IMG_SRC_PATTERN.matcher(rawHtml);
        if (m.find()) {
            return m.group(1);
        }
        String trimmed = rawHtml.trim();
        return trimmed.toLowerCase().startsWith('http') ? trimmed : null;
    }
    private class SkuOption {
        String size;
        String color;
    }
    private static List<SkuOption> findAvailableOptions(Id productId) {
        List<SkuOption> options = new List<SkuOption>();
        List<AggregateResult> stocked = [
            SELECT SKU__c
            FROM SKU_Inventory__c
            WHERE SKU__r.Product__c = :productId
            GROUP BY SKU__c
            HAVING SUM(Quantity_On_Hand__c) > 0
        ];
        if (stocked.isEmpty()) {
            return options;
        }
        Set<Id> stockedSkuIds = new Set<Id>();
        for (AggregateResult ar : stocked) {
            stockedSkuIds.add((Id) ar.get('SKU__c'));
        }
        List<SKU__c> skus = [
            SELECT Size__c, Color__c
            FROM SKU__c
            WHERE Id IN :stockedSkuIds
            ORDER BY Color__c, Size__c
        ];
        for (SKU__c s : skus) {
            SkuOption opt = new SkuOption();
            opt.size = s.Size__c;
            opt.color = s.Color__c;
            options.add(opt);
        }
        return options;
    }
    private static String formatAvailableOptions(List<SkuOption> options) {
        List<String> labels = new List<String>();
        for (SkuOption option : options) {
            labels.add(option.size + ' / ' + option.color);
        }
        return String.join(labels, ', ');
    }
}
