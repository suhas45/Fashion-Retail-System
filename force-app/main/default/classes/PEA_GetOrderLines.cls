/**
 * Thin agent-facing wrapper - one @InvocableMethod per class in this org.
 * Looks up order lines for the Product Exchange Assistant agent, either by
 * the authenticated customer's Contact/Account or by a plain order number.
 * Supports an optional latestOnly flag to return only the customer's most
 * recent order based on Order Effective Date.
 * Wired to Agent Script with target: "apex://PEA_GetOrderLines".
 */
public with sharing class PEA_GetOrderLines {
    @InvocableMethod(
        label='Get Order Lines PEA'
        description='Looks up the customer order lines by order number, or by authenticated Contact/Account. When latestOnly is true, returns only the most recent order.'
    )
    public static List<PEA_ExchangeService.GetOrderLinesResponse> run(List<PEA_ExchangeService.GetOrderLinesRequest> inputs) {
        return PEA_ExchangeService.getOrderLines(inputs);
    }
}