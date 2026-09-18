public with sharing class PEA_CheckSkuAvailability {

    public class ActionRequest {
        @InvocableVariable(
            label='SKU Availability Request'
            description='Size and color selection for the exchange.'
            required=true
        )
        public PEA_ExchangeService.CheckAvailabilityRequest request;
    }

    @InvocableMethod(
        label='Check SKU Availability PEA'
        description='Checks live stock for a requested size/color of the SKU on the selected order line.'
    )
    public static List<PEA_ExchangeService.CheckAvailabilityResponse> run(
        List<ActionRequest> inputs
    ) {
        List<PEA_ExchangeService.CheckAvailabilityRequest> requests =
            new List<PEA_ExchangeService.CheckAvailabilityRequest>();

        for (ActionRequest input : inputs) {
            if (input != null && input.request != null) {
                requests.add(input.request);
            }
        }

        return PEA_ExchangeService.checkAvailability(requests);
    }
}