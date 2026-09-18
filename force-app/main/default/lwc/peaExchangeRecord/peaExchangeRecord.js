import { LightningElement, api } from 'lwc';

export default class PeaExchangeRecord extends LightningElement {
    @api configuration;

    _value = {};

    @api
    get value() {
        return this._value;
    }

    set value(v) {
        this._value = v || {};
    }

    get result() {
        return this._value || {};
    }

    get exchangeNumber() {
        return this.result.exchangeNumber || '';
    }

    get newProduct() {
        return this.result.newSkuName || '';
    }

    get newVariant() {
        return this.formatVariant(
            this.result.newSize,
            this.result.newColor
        );
    }

    formatVariant(size, color) {
        if (size && color) {
            return `${size} / ${color}`;
        }

        return size || color || '';
    }
}
