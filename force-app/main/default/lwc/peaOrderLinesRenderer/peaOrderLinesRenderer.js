import { LightningElement, api } from 'lwc';

export default class PeaOrderLinesRenderer extends LightningElement {
    @api configuration;

    _value;

    @api
    get value() {
        return this._value;
    }

    set value(v) {
        this._value = v;
        console.log(
            'PEA Order Lines CLT value:',
            JSON.stringify(v)
        );
    }

    get result() {
        return this._value || {};
    }

    get found() {
        return this.result.found === true;
    }

    get lines() {
        return Array.isArray(this.result.lines)
            ? this.result.lines
            : [];
    }

    get totalFound() {
        return this.result.totalFound || this.lines.length;
    }

    get ordersFoundLabel() {
        const count = this.totalFound;
        return `${count} order${count === 1 ? '' : 's'} found`;
    }

    get displayLines() {
        return this.lines.map((line, index) => {
            const displaySkuName =
                line.skuName || line.productName || 'Product';

            return {
                ...line,

                key: line.orderLineId || `order-line-${index}`,

                // Number user can type in chat
                selectionNumber: index + 1,

                displaySkuName,

                hasProductImage: Boolean(line.productImageUrl),

                displayPrice:
                    line.price !== null && line.price !== undefined
                        ? `$${Number(line.price).toFixed(2)}`
                        : '-',

                exchangePrompt: `I want to exchange ${displaySkuName}`
            };
        });
    }

    // Groups lines by order and sorts orders by order start date
    // (EffectiveDate), most recent order first. The Apex query already
    // returns lines pre-sorted this way; the grouping/sort here just makes
    // the component resilient to callers that don't guarantee that order.
    get orders() {
        const groups = new Map();

        for (const line of this.displayLines) {
            const orderKey = line.orderNumber || 'unknown';

            if (!groups.has(orderKey)) {
                groups.set(orderKey, {
                    key: orderKey,
                    orderNumber: line.orderNumber,
                    orderDate: line.orderDate,
                    displayOrderDate: line.orderDate
                        ? new Date(`${line.orderDate}T00:00:00`).toLocaleDateString(
                              undefined,
                              { year: 'numeric', month: 'short', day: 'numeric' }
                          )
                        : '',
                    lines: []
                });
            }

            groups.get(orderKey).lines.push(line);
        }

        return Array.from(groups.values()).sort((a, b) =>
            (b.orderDate || '').localeCompare(a.orderDate || '')
        );
    }

    get hasOrders() {
        return this.orders.length > 0;
    }

    // configuration.util.sendTextMessage is injected by the Agentforce
    // runtime for output CLTs and sends text into the conversation as if
    // the customer had typed it. Falls back to a custom event for hosts
    // that don't provide it.
    handleExchangeClick(event) {
        const prompt = event.currentTarget?.dataset?.prompt;
        if (!prompt) {
            return;
        }

        const sendTextMessage = this.configuration?.util?.sendTextMessage;
        if (typeof sendTextMessage === 'function') {
            sendTextMessage.call(this.configuration.util, prompt);
            return;
        }

        this.dispatchEvent(
            new CustomEvent('exchangerequest', {
                detail: { prompt },
                bubbles: true,
                composed: true
            })
        );
    }
}