import { LightningElement, api } from 'lwc';

export default class PeaAvailableOptions extends LightningElement {
    @api configuration;

    _value = {};

    @api
    get value() {
        return this._value;
    }

    set value(v) {
        this._value = v || {};

        console.log(
            'PEA Available Options CLT value:',
            JSON.stringify(this._value)
        );
    }

    get result() {
        return this._value || {};
    }

    get options() {
        if (!Array.isArray(this.result.options)) {
            return [];
        }

        return this.result.options.map((option, index) => {
            const size = option.size || '';
            const color = option.color || '';

            return {
                ...option,

                key: option.skuId || `option-${index}`,

                displayLabel:
                    size && color
                        ? `${size} / ${color}`
                        : size || color || 'Available option',

                displayPrice:
                    option.price !== null &&
                    option.price !== undefined
                        ? `$${Number(option.price).toFixed(2)}`
                        : ''
            };
        });
    }

    get hasOptions() {
        return this.options.length > 0;
    }

    handleOptionClick(event) {
        const skuId =
            event.currentTarget?.dataset?.skuId;

        const size =
            event.currentTarget?.dataset?.size;

        const color =
            event.currentTarget?.dataset?.color;

        if (!skuId) {
            return;
        }

        console.log(
            'Selected exchange option:',
            JSON.stringify({
                skuId,
                size,
                color
            })
        );

        /*
         * Send the customer's selection into the Agentforce
         * conversation.
         *
         * The Agent will then re-check availability,
         * ask for confirmation, and finally call
         * Create_Exchange.
         */
        let prompt = `I want to exchange for ${size}`;

        if (color) {
            prompt += ` / ${color}`;
        }

        const sendTextMessage =
            this.configuration?.util?.sendTextMessage;

        if (typeof sendTextMessage === 'function') {
            sendTextMessage.call(
                this.configuration.util,
                prompt
            );

            return;
        }

        /*
         * Fallback event for hosts that don't provide
         * sendTextMessage.
         */
        this.dispatchEvent(
            new CustomEvent('optionselected', {
                detail: {
                    skuId,
                    size,
                    color,
                    prompt
                },
                bubbles: true,
                composed: true
            })
        );
    }
}