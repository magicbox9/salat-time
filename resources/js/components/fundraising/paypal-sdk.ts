import type { PayPalConfig } from './types';

/** The few pieces of the PayPal JavaScript SDK the donate panel uses. */
export type PayPalButtonsInstance = {
    render: (container: HTMLElement) => Promise<void>;
    close?: () => Promise<void>;
    isEligible?: () => boolean;
};

type ButtonActions = {
    resolve: () => Promise<void>;
    reject: () => Promise<void>;
};

export type PayPalButtonsOptions = {
    style?: Record<string, string | number | boolean>;
    onClick?: (data: unknown, actions: ButtonActions) => Promise<void> | void;
    createOrder: () => Promise<string>;
    onApprove: (data: { orderID: string }) => Promise<void>;
    onCancel?: (data: { orderID: string }) => void;
    onError?: (error: unknown) => void;
};

export type PayPalNamespace = {
    Buttons: (options: PayPalButtonsOptions) => PayPalButtonsInstance;
};

declare global {
    interface Window {
        paypal?: PayPalNamespace;
    }
}

let pending: Promise<PayPalNamespace> | null = null;
let pendingSrc = '';

/**
 * Loads PayPal's SDK once, only when PayPal is offered and chosen. The
 * merchant-id is the mosque's account (the payee of the orders), so PayPal
 * shows the mosque, never the platform, as the one being paid.
 */
export function loadPayPal(config: PayPalConfig): Promise<PayPalNamespace> {
    const params = new URLSearchParams({
        'client-id': config.client_id,
        'merchant-id': config.merchant,
        currency: 'EUR',
        intent: 'capture',
        components: 'buttons',
    });
    const src = `${config.sdk_url}?${params.toString()}`;

    if (pending && pendingSrc === src) {
        return pending;
    }

    document
        .querySelectorAll('script[data-salat-paypal]')
        .forEach((node) => node.remove());
    pendingSrc = src;
    pending = new Promise<PayPalNamespace>((resolve, reject) => {
        const script = document.createElement('script');
        script.src = src;
        script.async = true;
        script.dataset.salatPaypal = 'true';
        // A failed load is forgotten, so the next visit to the panel tries again.
        const fail = (reason: string) => {
            pending = null;
            pendingSrc = '';
            script.remove();
            reject(new Error(reason));
        };
        script.onload = () =>
            window.paypal ? resolve(window.paypal) : fail('paypal-missing');
        script.onerror = () => fail('paypal-unreachable');
        document.head.appendChild(script);
    });

    return pending;
}
