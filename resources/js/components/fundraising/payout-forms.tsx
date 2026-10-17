import { useForm } from '@inertiajs/react';
import { BadgeCheck, Clock } from 'lucide-react';
import { useFormatDate } from '@/components/claims/use-format-date';
import { Field } from '@/components/manage/fields';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Spinner } from '@/components/ui/spinner';
import { useT } from '@/lib/i18n';
import type { PayoutMethod } from './types';

/** "Verified on …" or "Waiting for verification". */
export function PayoutStatus({ payout }: { payout: PayoutMethod | null }) {
    const t = useT();
    const formatDate = useFormatDate();

    if (!payout) {
        return (
            <span className="rounded-full bg-muted px-2.5 py-0.5 text-xs text-muted-foreground">
                {t('fundraising.payout_none')}
            </span>
        );
    }

    return payout.verified ? (
        <span className="inline-flex items-center gap-1 rounded-full bg-emerald-500/15 px-2.5 py-0.5 text-xs font-medium text-emerald-800 dark:text-emerald-300">
            <BadgeCheck className="size-3.5" aria-hidden />
            {t('fundraising.payout_verified_on', {
                date: formatDate(payout.verified_at),
            })}
        </span>
    ) : (
        <span className="inline-flex items-center gap-1 rounded-full bg-amber-500/15 px-2.5 py-0.5 text-xs font-medium text-amber-900 dark:text-amber-300">
            <Clock className="size-3.5" aria-hidden />
            {t('fundraising.payout_waiting')}
        </span>
    );
}

export function PayPalForm({
    url,
    payout,
}: {
    url: string;
    payout: PayoutMethod | null;
}) {
    const t = useT();
    const form = useForm({
        type: 'paypal',
        paypal_email: payout?.paypal_email ?? '',
        paypal_merchant_id: payout?.paypal_merchant_id ?? '',
    });

    return (
        <form
            onSubmit={(event) => {
                event.preventDefault();
                form.post(url, { preserveScroll: true });
            }}
            className="grid gap-4"
        >
            <Field
                id="paypal_email"
                label={t('fundraising.field_paypal_email')}
                hint={t('fundraising.paypal_email_hint')}
                error={form.errors.paypal_email}
            >
                <Input
                    id="paypal_email"
                    type="email"
                    dir="ltr"
                    maxLength={200}
                    value={form.data.paypal_email}
                    onChange={(event) =>
                        form.setData('paypal_email', event.target.value)
                    }
                />
            </Field>
            <Field
                id="paypal_merchant_id"
                label={t('fundraising.field_merchant_id')}
                hint={t('fundraising.merchant_id_hint')}
                error={form.errors.paypal_merchant_id}
            >
                <Input
                    id="paypal_merchant_id"
                    dir="ltr"
                    maxLength={13}
                    className="font-mono uppercase sm:w-56"
                    value={form.data.paypal_merchant_id}
                    onChange={(event) =>
                        form.setData(
                            'paypal_merchant_id',
                            event.target.value.toUpperCase(),
                        )
                    }
                />
            </Field>
            <Button
                type="submit"
                disabled={form.processing}
                className="justify-self-start"
            >
                {form.processing && <Spinner />}
                {t('fundraising.save_account')}
            </Button>
        </form>
    );
}

export function BankForm({
    url,
    payout,
}: {
    url: string;
    payout: PayoutMethod | null;
}) {
    const t = useT();
    const form = useForm({
        type: 'bank',
        account_holder: payout?.account_holder ?? '',
        iban: '',
        bic: payout?.bic ?? '',
        bank_name: payout?.bank_name ?? '',
    });

    return (
        <form
            onSubmit={(event) => {
                event.preventDefault();
                form.post(url, {
                    preserveScroll: true,
                    onSuccess: () => form.setData('iban', ''),
                });
            }}
            className="grid gap-4"
        >
            <Field
                id="account_holder"
                label={t('fundraising.field_account_holder')}
                hint={t('fundraising.account_holder_hint')}
                error={form.errors.account_holder}
            >
                <Input
                    id="account_holder"
                    maxLength={200}
                    required
                    value={form.data.account_holder}
                    onChange={(event) =>
                        form.setData('account_holder', event.target.value)
                    }
                />
            </Field>
            <Field
                id="iban"
                label="IBAN"
                hint={
                    payout?.iban_masked
                        ? t('fundraising.iban_keep_hint', {
                              iban: payout.iban_masked,
                          })
                        : t('fundraising.iban_hint')
                }
                error={form.errors.iban}
            >
                <Input
                    id="iban"
                    dir="ltr"
                    autoComplete="off"
                    spellCheck={false}
                    maxLength={42}
                    required={!payout?.iban_masked}
                    placeholder={
                        payout?.iban_masked ??
                        'FR76 3000 6000 0112 3456 7890 189'
                    }
                    className="font-mono uppercase"
                    value={form.data.iban}
                    onChange={(event) =>
                        form.setData('iban', event.target.value.toUpperCase())
                    }
                />
            </Field>
            <div className="grid gap-4 sm:grid-cols-2">
                <Field
                    id="bic"
                    label="BIC"
                    hint={t('fundraising.bic_hint')}
                    error={form.errors.bic}
                >
                    <Input
                        id="bic"
                        dir="ltr"
                        maxLength={11}
                        className="font-mono uppercase"
                        value={form.data.bic}
                        onChange={(event) =>
                            form.setData(
                                'bic',
                                event.target.value.toUpperCase(),
                            )
                        }
                    />
                </Field>
                <Field
                    id="bank_name"
                    label={t('fundraising.field_bank_name')}
                    error={form.errors.bank_name}
                >
                    <Input
                        id="bank_name"
                        maxLength={120}
                        value={form.data.bank_name}
                        onChange={(event) =>
                            form.setData('bank_name', event.target.value)
                        }
                    />
                </Field>
            </div>
            <Button
                type="submit"
                disabled={form.processing}
                className="justify-self-start"
            >
                {form.processing && <Spinner />}
                {t('fundraising.save_account')}
            </Button>
        </form>
    );
}
