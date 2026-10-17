import { CreditCard, Landmark } from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import type { AvailableMethods, DonationMethod } from './types';

const OPTIONS: { method: DonationMethod; icon: LucideIcon }[] = [
    { method: 'paypal', icon: CreditCard },
    { method: 'bank', icon: Landmark },
];

/** PayPal (or a card through PayPal) or a SEPA bank transfer, as radio cards. */
export function MethodPicker({
    methods,
    value,
    onChange,
}: {
    methods: AvailableMethods;
    value: DonationMethod;
    onChange: (method: DonationMethod) => void;
}) {
    const t = useT();
    const options = OPTIONS.filter((option) => methods[option.method]);

    if (options.length < 2) {
        return null;
    }

    return (
        <div
            role="radiogroup"
            aria-label={t('fundraising.choose_method')}
            className="grid grid-cols-2 gap-2"
        >
            {options.map(({ method, icon: Icon }) => {
                const checked = value === method;

                return (
                    <button
                        key={method}
                        type="button"
                        role="radio"
                        aria-checked={checked}
                        onClick={() => onChange(method)}
                        className={cn(
                            'flex flex-col items-start gap-1 rounded-xl border p-3 text-start transition-all outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50',
                            checked
                                ? 'border-primary bg-primary/5 shadow-sm ring-1 ring-primary'
                                : 'bg-background hover:border-primary/40',
                        )}
                    >
                        <Icon
                            className={cn(
                                'size-5',
                                checked
                                    ? 'text-primary'
                                    : 'text-muted-foreground',
                            )}
                            aria-hidden
                        />
                        <span className="text-sm font-semibold">
                            {t(`fundraising.method_${method}`)}
                        </span>
                        <span className="text-xs text-muted-foreground">
                            {t(`fundraising.method_${method}_hint`)}
                        </span>
                    </button>
                );
            })}
        </div>
    );
}
