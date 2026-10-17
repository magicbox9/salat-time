import { useId } from 'react';
import InputError from '@/components/input-error';
import { Input } from '@/components/ui/input';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { useMoney } from './format';

type Props = {
    presets: number[];
    /** The chosen preset (cents), or null when a custom amount is typed. */
    preset: number | null;
    custom: string;
    onPreset: (cents: number) => void;
    onCustom: (text: string) => void;
    error?: string;
};

/** The custom field fills what the last row of chips leaves free. */
const CUSTOM_SPAN: Record<number, string> = {
    0: 'min-[420px]:col-span-3',
    1: 'min-[420px]:col-span-2',
    2: 'min-[420px]:col-span-1',
};

/** Suggested amounts as large chips, or any amount typed in euros. */
export function AmountPicker({
    presets,
    preset,
    custom,
    onPreset,
    onCustom,
    error,
}: Props) {
    const t = useT();
    const money = useMoney();
    const customId = useId();

    return (
        <fieldset className="space-y-3">
            <legend className="mb-3 text-sm font-medium">
                {t('fundraising.choose_amount')}
            </legend>
            <div className="grid grid-cols-3 gap-2">
                {presets.map((cents) => {
                    const selected = preset === cents && custom === '';

                    return (
                        <button
                            key={cents}
                            type="button"
                            aria-pressed={selected}
                            onClick={() => onPreset(cents)}
                            className={cn(
                                'h-12 rounded-xl border text-base font-semibold tabular-nums transition-all outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50',
                                selected
                                    ? 'border-primary bg-primary text-primary-foreground shadow-sm'
                                    : 'bg-background hover:border-primary/40 hover:bg-accent',
                            )}
                        >
                            <span dir="ltr">{money(cents)}</span>
                        </button>
                    );
                })}
                <label
                    htmlFor={customId}
                    className={cn(
                        'relative col-span-3 flex items-center rounded-xl border bg-background transition-colors focus-within:border-ring focus-within:ring-[3px] focus-within:ring-ring/50',
                        CUSTOM_SPAN[presets.length % 3],
                        custom !== '' && 'border-primary',
                    )}
                >
                    <span className="sr-only">
                        {t('fundraising.other_amount')}
                    </span>
                    <Input
                        id={customId}
                        inputMode="decimal"
                        autoComplete="off"
                        dir="ltr"
                        placeholder={t('fundraising.other_amount')}
                        value={custom}
                        onChange={(event) =>
                            onCustom(event.target.value.slice(0, 10))
                        }
                        aria-invalid={error ? true : undefined}
                        className="h-12 border-0 pe-8 text-base font-semibold shadow-none focus-visible:ring-0"
                    />
                    <span
                        className="pointer-events-none absolute end-3 text-muted-foreground"
                        aria-hidden
                    >
                        €
                    </span>
                </label>
            </div>
            <InputError message={error} />
        </fieldset>
    );
}
