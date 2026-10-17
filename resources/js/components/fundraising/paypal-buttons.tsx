import { router } from '@inertiajs/react';
import { AlertCircle } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { api, ApiError, errorMessage } from '@/components/mosque/api';
import { Skeleton } from '@/components/ui/skeleton';
import { useT } from '@/lib/i18n';
import { loadPayPal } from './paypal-sdk';
import type { PayPalButtonsInstance } from './paypal-sdk';
import type { PayPalConfig } from './types';

type Props = {
    config: PayPalConfig;
    slug: string;
    /** Checks the form before PayPal opens; false keeps PayPal closed. */
    validate: () => boolean;
    /** The donor's details at the moment they click. */
    donor: () => Record<string, unknown>;
    onError: (message: string | null, fields?: Record<string, string>) => void;
};

/**
 * PayPal's own buttons (PayPal account or card). The order is created and
 * captured by our server: the amount and the mosque's account come from
 * there, never from this page.
 */
export function PayPalButtons({
    config,
    slug,
    validate,
    donor,
    onError,
}: Props) {
    const t = useT();
    const container = useRef<HTMLDivElement>(null);
    const latest = useRef({ validate, donor, onError });
    // Our own calls explain their failure; PayPal's generic onError, which
    // follows them, must not replace that message.
    const reported = useRef(false);
    const [state, setState] = useState<
        'loading' | 'ready' | 'error' | 'capturing'
    >('loading');

    useEffect(() => {
        latest.current = { validate, donor, onError };
    });

    useEffect(() => {
        let cancelled = false;
        let buttons: PayPalButtonsInstance | null = null;

        loadPayPal(config)
            .then((paypal) => {
                if (cancelled || !container.current) {
                    return;
                }

                buttons = paypal.Buttons({
                    style: {
                        layout: 'vertical',
                        shape: 'pill',
                        color: 'gold',
                        label: 'paypal',
                        height: 46,
                    },
                    onClick: (_data, actions) => {
                        reported.current = false;
                        latest.current.onError(null);

                        return latest.current.validate()
                            ? actions.resolve()
                            : actions.reject();
                    },
                    createOrder: async () => {
                        try {
                            const order = await api<{ order_id: string }>(
                                'POST',
                                `/campaigns/${slug}/donations/paypal`,
                                latest.current.donor(),
                            );

                            return order.order_id;
                        } catch (error) {
                            const fields =
                                error instanceof ApiError &&
                                error.status === 422
                                    ? Object.fromEntries(
                                          Object.entries(error.errors).map(
                                              ([key, list]) => [key, list[0]],
                                          ),
                                      )
                                    : undefined;
                            reported.current = true;
                            latest.current.onError(
                                errorMessage(error, t),
                                fields,
                            );

                            throw error;
                        }
                    },
                    onApprove: async ({ orderID }) => {
                        setState('capturing');

                        try {
                            const result = await api<{
                                status: string;
                                redirect?: string;
                            }>(
                                'POST',
                                `/campaigns/${slug}/donations/paypal/${orderID}/capture`,
                            );

                            if (result.redirect) {
                                router.visit(result.redirect);
                            }
                        } catch (error) {
                            reported.current = true;
                            setState('ready');
                            latest.current.onError(errorMessage(error, t));
                        }
                    },
                    onCancel: ({ orderID }) => {
                        void api(
                            'POST',
                            `/campaigns/${slug}/donations/paypal/${orderID}/cancel`,
                        ).catch(() => undefined);
                    },
                    onError: () => {
                        if (!reported.current) {
                            latest.current.onError(
                                t('fundraising.paypal_error'),
                            );
                        }
                    },
                });

                return buttons.render(container.current).then(() => {
                    if (!cancelled) {
                        setState('ready');
                    }
                });
            })
            .catch(() => !cancelled && setState('error'));

        return () => {
            cancelled = true;
            void buttons?.close?.().catch(() => undefined);
        };
        // The buttons are drawn once per account; the form is read through refs.
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [config.client_id, config.merchant, config.sdk_url, slug]);

    return (
        <div className="space-y-2">
            {state === 'loading' && (
                <div
                    className="space-y-2"
                    aria-busy="true"
                    aria-label={t('fundraising.paypal_loading')}
                >
                    <Skeleton className="h-[46px] rounded-full" />
                    <Skeleton className="h-[46px] rounded-full" />
                </div>
            )}
            {state === 'error' && (
                <p className="flex items-start gap-2 rounded-xl bg-destructive/10 px-3 py-2.5 text-sm text-destructive-foreground">
                    <AlertCircle
                        className="mt-0.5 size-4 shrink-0"
                        aria-hidden
                    />
                    {t('fundraising.paypal_unreachable')}
                </p>
            )}
            {state === 'capturing' && (
                <p
                    className="rounded-xl bg-primary/10 px-3 py-2.5 text-sm font-medium text-primary"
                    role="status"
                >
                    {t('fundraising.paypal_capturing')}
                </p>
            )}
            <div
                ref={container}
                className={
                    state === 'capturing'
                        ? 'pointer-events-none opacity-50'
                        : undefined
                }
            />
            {config.sandbox && (
                <p className="text-center text-xs text-muted-foreground">
                    {t('fundraising.paypal_sandbox')}
                </p>
            )}
        </div>
    );
}
