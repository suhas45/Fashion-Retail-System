/**
 * Thin agent-facing wrapper - one @InvocableMethod per class in this org.
 * Looks up order lines for the Product Exchange Assistant agent, either by
 * the authenticated customer's Contact/Account or by a plain order number.
 * Wired to Agent Script with target: "apex://PEA_GetOrderLines".
 */
public with sharing class PEA_GetOrderLines {

    @InvocableMethod(
        label='Get Order Lines PEA'
        description='Looks up the customer\'s order lines by order number, or by their authenticated Contact/Account when no order number is given.')
    public static List<PEA_ExchangeService.GetOrderLinesResponse> run(List<PEA_ExchangeService.GetOrderLinesRequest> inputs) {
        return PEA_ExchangeService.getOrderLines(inputs);
    }
}