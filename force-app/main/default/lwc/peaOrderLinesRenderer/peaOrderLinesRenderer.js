import { LightningElement, api } from 'lwc';

export default class PeaOrderLinesRenderer extends LightningElement {
    /**
     * Salesforce passes the Lightning Type output here.
     *
     * Expected structure:
     *
     * {
     *   found: true,
     *   contactId: "...",
     *   contactName: "...",
     *   accountId: "...",
     *   accountName: "...",
     *   totalFound: 2,
     *   primaryOrderLineId: "...",
     *   primarySkuId: "...",
     *   primaryProductName: "...",
     *   lines: [...]
     * }
     */
    @api value;

    get result() {
        return this.value || {};
    }

    get found() {
        return this.result.found === true;
    }

    get lines() {
        return Array.isArray(this.result.lines)
            ? this.result.lines
            : [];
    }

    get hasLines() {
        return this.lines.length > 0;
    }

    get totalFound() {
        return this.result.totalFound || this.lines.length;
    }

    get customerName() {
        return this.result.contactName || 'Customer';
    }

    get accountName() {
        return this.result.accountName || '';
    }

    get hasAccountName() {
        return Boolean(this.accountName);
    }

    get displayLines() {
        return this.lines.map((line) => ({
            ...line,

            // Used by the template for conditional display.
            hasProductName: Boolean(line.productName),
            hasSkuName: Boolean(line.skuName),
            hasOrderNumber: Boolean(line.orderNumber),
            hasOrderStatus: Boolean(line.orderStatus),
            hasColor: Boolean(line.color),
            hasSize: Boolean(line.size),
            hasQuantity: line.quantity !== null && line.quantity !== undefined,
            hasPrice: line.price !== null && line.price !== undefined
        }));
    }
}