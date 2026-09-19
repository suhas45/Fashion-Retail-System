import { LightningElement, api } from 'lwc';

// Editor CLT (target lightning__AgentforceInput) for the SKU_Availability
// action's CheckAvailabilityRequest input - shown instead of the agent
// asking "what size or color?" in plain text. currentSkuId arrives
// pre-filled on `value` (set by the agent from context) and is carried
// through untouched; only desiredSize/desiredColor are user-edited here.
// Plain free-text fields, no options lookup - if the typed combination
// isn't in stock, the agent's next message reports the actual available
// options via the SKU_Availability action's existing fallback behavior.
export default class PeaExchangeSizeColorForm extends LightningElement {
    @api configuration;
    isButtonVisible = false; 

    _value = {};
    desiredSize = '';
    desiredColor = '';

    @api
    get value() {
        return this._value;
    }

    set value(v) {
        this._value = v || {};
        this.desiredSize = this._value.desiredSize || '';
        this.desiredColor = this._value.desiredColor || '';
    }

    get isSubmitDisabled() {
        return !this.desiredSize;
    }

    handleSizeChange(event) {
        this.desiredSize = event.target.value;
        this.notifyValueChange();
    }

    handleColorChange(event) {
        this.desiredColor = event.target.value;
        this.notifyValueChange();
    }

    handleSubmit() {
        if (!this.desiredSize) {
            return;
        }
        this.notifyValueChange();
    }

    notifyValueChange() {
        this.dispatchEvent(
            new CustomEvent('valuechange', {
                detail: {
                    value: {
                        ...this._value,
                        desiredSize: this.desiredSize,
                        desiredColor: this.desiredColor
                    }
                },
                bubbles: true,
                composed: true
            })
        );
    }
}
