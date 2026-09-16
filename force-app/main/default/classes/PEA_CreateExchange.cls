/**
 * Thin agent-facing wrapper - one @InvocableMethod per class in this org.
 * Creates the Exchange__c record for a confirmed SKU swap on a selected
 * order line, verifying order-line ownership when the customer is
 * authenticated.
 * Wired to Agent Script with target: "apex://PEA_CreateExchange".
 */
public with sharing class PEA_CreateExchange {

    @InvocableMethod(
        label='Create Exchange PEA'
        description='Creates the Exchange record for the confirmed SKU swap on the selected order line.')
    public static List<PEA_ExchangeService.CreateExchangeResponse> run(List<PEA_ExchangeService.CreateExchangeRequest> inputs) {
        return PEA_ExchangeService.createExchange(inputs);
    }
}