public with sharing class PEA_CheckSkuAvailability {

    public class ActionRequest {

        @InvocableVariable(
            label='Current SKU Id'
            description='SKU Id of the order line being exchanged.'
            required=true
        )
        public String currentSkuId;

        @InvocableVariable(
            label='SKU Availability Request'
            description='Desired size and color selected by the customer.'
            required=true
        )
        public PEA_ExchangeService.CheckAvailabilityInput request;
    }

    public class ActionResponse {

        @InvocableVariable(
            label='Response'
            description='Complete SKU availability result.'
        )
        public PEA_ExchangeService.CheckAvailabilityResponse response;
    }

    @InvocableMethod(
        label='Check SKU Availability PEA'
        description='Checks live stock for a requested size/color of the SKU on the selected order line.'
    )
    public static List<ActionResponse> run(
        List<ActionRequest> inputs
    ) {

        List<PEA_ExchangeService.CheckAvailabilityRequest> requests =
            new List<PEA_ExchangeService.CheckAvailabilityRequest>();

        for (ActionRequest input : inputs) {

            if (input == null || input.request == null) {
                continue;
            }

            PEA_ExchangeService.CheckAvailabilityRequest req =
                new PEA_ExchangeService.CheckAvailabilityRequest();

            req.currentSkuId = input.currentSkuId;
            req.desiredSize = input.request.desiredSize;
            req.desiredColor = input.request.desiredColor;

            requests.add(req);
        }

        List<PEA_ExchangeService.CheckAvailabilityResponse> results =
            PEA_ExchangeService.checkAvailability(requests);

        List<ActionResponse> output =
            new List<ActionResponse>();

        for (PEA_ExchangeService.CheckAvailabilityResponse result : results) {

            ActionResponse wrapper = new ActionResponse();

            wrapper.response = result;

            output.add(wrapper);
        }

        return output;
    }
}