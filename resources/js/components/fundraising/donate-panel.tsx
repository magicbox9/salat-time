import { router } from '@inertiajs/react';
import { HeartHandshake, Lock, ShieldCheck } from 'lucide-react';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Spinner } from '@/components/ui/spinner';
import { useT } from '@/lib/i18n';
import { AmountPicker } from './amount-picker';
import { DonorFields } from './donor-fields';
import type { DonorValues } from './donor-fields';
import { parseEuros, useMoney } from './format';
import { MethodPicker } from './method-picker';
import { PayPalButtons } from './paypal-buttons';
import type { AvailableMethods, DonationMethod, PayPalConfig } from './types';

type Props = {
    slug: string;
    mosqueName: string;
    methods: AvailableMethods;
    paypal: PayPalConfig | null;
    presets: number[];
    limits: { min: number; max: number };
    donor: { name: string; email: string } | null;
};

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/**
 * Giving to the campaign: an amount, who gives, and how (PayPal or a bank
 * transfer). Says plainly that the money goes to the mosque's own account.
 */
export function DonatePanel({
    slug,
    mosqueName,
    methods,
    paypal,
    presets,
    limits,
    donor,
}: Props) {
    const t = useT();
    const money = useMoney();
    const [preset, setPreset] = useState<number | null>(
        presets[2] ?? presets[0] ?? null,
    );
    const [custom, setCustom] = useState('');
    const [values, setValues] = useState<DonorValues>({
        name: donor?.name ?? '',
        email: donor?.email ?? '',
        anonymous: false,
        message: '',
    });
    const [method, setMethod] = useState<DonationMethod>(
        methods.paypal && paypal ? 'paypal' : 'bank',
    );
    const [errors, setErrors] = useState<Record<string, string | undefined>>(
        {},
    );
    const [notice, setNotice] = useState<string | null>(null);
    const [sending, setSending] = useState(false);

    const amount = custom !== '' ? parseEuros(custom) : preset;

    const payload = () => ({
        amount,
        donor_name: values.name.trim(),
        donor_email: values.email.trim(),
        anonymous: values.anonymous,
        message: values.message.trim() || null,
    });

    const validate = (): boolean => {
        const next: Record<string, string> = {};

        if (amount === null || amount < limits.min || amount > limits.max) {
            next.amount = t('fundraising.v_amount_range', {
                min: money(limits.min),
                max: money(limits.max),
            });
        }

        if (values.name.trim().length < 2) {
            next.donor_name = t('fundraising.v_name');
        }

        if (!EMAIL.test(values.email.trim())) {
            next.donor_email = t('fundraising.v_email');
        }

        setErrors(next);

        return Object.keys(next).length === 0;
    };

    const pledge = (event: React.FormEvent) => {
        event.preventDefault();
        setNotice(null);

        if (!validate()) {
            return;
        }

        router.post(`/campaigns/${slug}/donations/bank`, payload(), {
            preserveScroll: true,
            onStart: () => setSending(true),
            onFinish: () => setSending(false),
            onError: (fieldErrors) => {
                setErrors(fieldErrors);
                setNotice(fieldErrors.method ?? null);
            },
        });
    };

    const showError = (
        message: string | null,
        fields?: Record<string, string>,
    ) => {
        setNotice(message);

        if (fields) {
            setErrors(fields);
        }
    };

    return (
        <section
            id="donate"
            aria-labelledby="donate-title"
            className="scroll-mt-24 rounded-3xl border bg-card p-5 shadow-sm sm:p-6"
        >
            <h2
                id="donate-title"
                className="flex items-center gap-2 text-lg font-semibold tracking-tight"
            >
                <HeartHandshake className="size-5 text-gold" aria-hidden />
                {t('fundraising.donate_title')}
            </h2>

            <form onSubmit={pledge} className="mt-5 grid gap-5" noValidate>
                <AmountPicker
                    presets={presets}
                    preset={preset}
                    custom={custom}
                    onPreset={(cents) => {
                        setPreset(cents);
                        setCustom('');
                    }}
                    onCustom={setCustom}
                    error={errors.amount}
                />

                <DonorFields
                    values={values}
                    onChange={setValues}
                    errors={errors}
                    signedIn={donor !== null}
                />

                <MethodPicker
                    methods={{
                        paypal: methods.paypal && paypal !== null,
                        bank: methods.bank,
                    }}
                    value={method}
                    onChange={setMethod}
                />

                {notice && (
                    <p
                        role="alert"
                        className="rounded-xl bg-destructive/10 px-3 py-2.5 text-sm text-destructive-foreground"
                    >
                        {notice}
                    </p>
                )}

                {method === 'paypal' && paypal ? (
                    <PayPalButtons
                        config={paypal}
                        slug={slug}
                        validate={validate}
                        donor={payload}
                        onError={showError}
                    />
                ) : (
                    <div className="grid gap-2">
                        <Button
                            type="submit"
                            size="lg"
                            className="h-12 rounded-full text-base"
                            disabled={sending}
                        >
                            {sending ? (
                                <Spinner />
                            ) : (
                                <Lock className="size-4" aria-hidden />
                            )}
                            {amount !== null && amount >= limits.min
                                ? t('fundraising.bank_submit_amount', {
                                      amount: money(amount),
                                  })
                                : t('fundraising.bank_submit')}
                        </Button>
                        <p className="text-center text-xs text-muted-foreground">
                            {t('fundraising.bank_submit_hint')}
                        </p>
                    </div>
                )}
            </form>

            <div className="mt-5 flex items-start gap-2.5 rounded-2xl bg-primary/5 p-3.5 text-sm">
                <ShieldCheck
                    className="mt-0.5 size-5 shrink-0 text-primary"
                    aria-hidden
                />
                <div className="space-y-1">
                    <p className="font-medium">
                        {t('fundraising.direct_title', { mosque: mosqueName })}
                    </p>
                    <p className="text-muted-foreground">
                        {t('fundraising.direct_body')}
                    </p>
                </div>
            </div>
        </section>
    );
}
