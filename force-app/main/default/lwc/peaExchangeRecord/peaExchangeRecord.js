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

        console.log(
            'PEA Exchange Record CLT value:',
            JSON.stringify(this._value)
        );
    }

    get result() {
        return this._value || {};
    }

    get exchangeNumber() {
        return this.result.exchangeNumber || '';
    }

    get status() {
        return this.result.status || '';
    }

    get orderNumber() {
        return this.result.orderNumber || '';
    }

    get originalProduct() {
        return this.result.originalSkuName || '';
    }

    get originalVariant() {
        return this.formatVariant(
            this.result.originalSize,
            this.result.originalColor
        );
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

    get originalPrice() {
        return this.formatPrice(this.result.originalPrice);
    }

    get newPrice() {
        return this.formatPrice(this.result.newPrice);
    }

    get priceDifference() {
        const value = this.result.priceDifference;

        if (value === null || value === undefined) {
            return '';
        }

        const amount = Number(value);

        if (amount > 0) {
            return `+$${amount.toFixed(2)}`;
        }

        if (amount < 0) {
            return `-$${Math.abs(amount).toFixed(2)}`;
        }

        return '$0.00';
    }

    get isSuccess() {
        return this.result.success === true;
    }

    formatVariant(size, color) {
        if (size && color) {
            return `${size} / ${color}`;
        }

        return size || color || '';
    }

    formatPrice(value) {
        if (value === null || value === undefined) {
            return '';
        }

        return `$${Number(value).toFixed(2)}`;
    }
}