/**
 * Thin agent-facing wrapper - one @InvocableMethod per class in this org.
 * Checks live stock for a requested size/color of the SKU on a selected
 * order line, and reports the other in-stock combinations when the
 * requested one is unavailable.
 * Wired to Agent Script with target: "apex://PEA_CheckSkuAvailability".
 */
public with sharing class PEA_CheckSkuAvailability {

    @InvocableMethod(
        label='Check SKU Availability PEA'
        description='Checks live stock for a requested size/color of the SKU on the selected order line.')
    public static List<PEA_ExchangeService.CheckAvailabilityResponse> run(List<PEA_ExchangeService.CheckAvailabilityRequest> inputs) {
        return PEA_ExchangeService.checkAvailability(inputs);
    }
}