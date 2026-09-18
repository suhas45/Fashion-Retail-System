/**
 * Thin agent-facing wrapper - one @InvocableMethod per class in this org.
 * Creates the Exchange__c record for a confirmed SKU swap on a selected
 * order line, verifying order-line ownership when the customer is
 * authenticated.
 * Wired to Agent Script with target: "apex://PEA_CreateExchange".
 */
public with sharing class PEA_CreateExchange {
    public class ActionResponse {
        @InvocableVariable(
            label='Response'
            description='Complete exchange creation result.'
        )
        public PEA_ExchangeService.CreateExchangeResponse response;
    }
    @InvocableMethod(
        label='Create Exchange PEA'
        description='Creates the Exchange record for the confirmed SKU swap on the selected order line.'
    )
    public static List<ActionResponse> run(
        List<PEA_ExchangeService.CreateExchangeRequest> inputs
    ) {
        List<PEA_ExchangeService.CreateExchangeResponse> results =
            PEA_ExchangeService.createExchange(inputs);
        List<ActionResponse> output =
            new List<ActionResponse>();
        for (PEA_ExchangeService.CreateExchangeResponse result : results) {
            ActionResponse wrapper = new ActionResponse();
            wrapper.response = result;
            output.add(wrapper);
        }
        return output;
    }
}