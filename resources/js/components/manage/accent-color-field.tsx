import { Check, TriangleAlert } from 'lucide-react';
import InputError from '@/components/input-error';
import { contrastRatio, HEX_COLOR } from '@/components/mosque/accent';
import { Input } from '@/components/ui/input';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';

type Props = {
    value: string;
    onChange: (value: string) => void;
    palette: string[];
    error?: string;
};

const LIGHT_TEXT = '#ffffff';
const DARK_TEXT = '#0b1a17';
const PAGE_LIGHT = '#fbfaf5';

/**
 * The colour of the mosque's site: a curated palette or any colour. Text on
 * the colour is white or near-black, whichever reads better; the check below
 * shows the contrast so the manager can see it stays legible.
 */
export function AccentColorField({ value, onChange, palette, error }: Props) {
    const t = useT();
    const valid = HEX_COLOR.test(value);
    const color = valid ? value.toLowerCase() : null;
    const onLight = color ? contrastRatio(color, LIGHT_TEXT) : 0;
    const onDark = color ? contrastRatio(color, DARK_TEXT) : 0;
    const text = onLight >= onDark ? LIGHT_TEXT : DARK_TEXT;
    const ratio = Math.max(onLight, onDark);
    const againstPage = color ? contrastRatio(color, PAGE_LIGHT) : 0;

    return (
        <div className="grid gap-3">
            <div>
                <p className="text-sm font-medium" id="accent-label">
                    {t('manage.accent')}
                </p>
                <p className="text-xs text-muted-foreground">
                    {t('manage.accent_hint')}
                </p>
            </div>

            <div
                role="radiogroup"
                aria-labelledby="accent-label"
                className="flex flex-wrap gap-2"
            >
                <button
                    type="button"
                    role="radio"
                    aria-checked={value === ''}
                    onClick={() => onChange('')}
                    title={t('manage.accent_default')}
                    className={cn(
                        'flex size-9 items-center justify-center rounded-full border-2 bg-primary text-primary-foreground transition-transform outline-none focus-visible:ring-2 focus-visible:ring-ring/60 motion-safe:hover:scale-105',
                        value === ''
                            ? 'border-foreground'
                            : 'border-transparent',
                    )}
                >
                    {value === '' && <Check className="size-4" />}
                    <span className="sr-only">
                        {t('manage.accent_default')}
                    </span>
                </button>
                {palette.map((swatch) => {
                    const active = color === swatch;

                    return (
                        <button
                            key={swatch}
                            type="button"
                            role="radio"
                            aria-checked={active}
                            aria-label={swatch}
                            onClick={() => onChange(swatch)}
                            style={{ backgroundColor: swatch }}
                            className={cn(
                                'flex size-9 items-center justify-center rounded-full border-2 transition-transform outline-none focus-visible:ring-2 focus-visible:ring-ring/60 motion-safe:hover:scale-105',
                                active
                                    ? 'border-foreground'
                                    : 'border-transparent',
                            )}
                        >
                            {active && (
                                <Check
                                    className="size-4"
                                    style={{
                                        color:
                                            contrastRatio(swatch, LIGHT_TEXT) >=
                                            contrastRatio(swatch, DARK_TEXT)
                                                ? LIGHT_TEXT
                                                : DARK_TEXT,
                                    }}
                                />
                            )}
                        </button>
                    );
                })}
            </div>

            <div className="flex flex-wrap items-center gap-2">
                <label
                    className="flex items-center gap-2 text-sm"
                    htmlFor="accent-custom"
                >
                    {t('manage.accent_custom')}
                </label>
                <input
                    type="color"
                    aria-label={t('manage.accent_custom')}
                    value={color ?? '#0f6b56'}
                    onChange={(event) => onChange(event.target.value)}
                    className="h-9 w-12 cursor-pointer rounded-md border bg-transparent p-1"
                />
                <Input
                    id="accent-custom"
                    value={value}
                    placeholder="#0f6b56"
                    maxLength={7}
                    dir="ltr"
                    onChange={(event) => onChange(event.target.value.trim())}
                    aria-invalid={(value !== '' && !valid) || undefined}
                    className="w-28 font-mono"
                />
            </div>

            {color && (
                <div className="flex flex-wrap items-center gap-3 rounded-xl border bg-muted/40 p-3">
                    <span
                        className="rounded-lg px-3 py-1.5 text-sm font-medium shadow-xs"
                        style={{ backgroundColor: color, color: text }}
                    >
                        {t('manage.accent_sample')}
                    </span>
                    <span className="flex items-center gap-1.5 text-xs">
                        {ratio >= 4.5 ? (
                            <Check
                                className="size-4 text-emerald-600 dark:text-emerald-400"
                                aria-hidden
                            />
                        ) : (
                            <TriangleAlert
                                className="size-4 text-amber-600"
                                aria-hidden
                            />
                        )}
                        <span>
                            {t('manage.accent_contrast', {
                                ratio: ratio.toFixed(1),
                            })}
                            {' · '}
                            {ratio >= 4.5
                                ? t('manage.accent_contrast_ok')
                                : t('manage.accent_contrast_low')}
                        </span>
                    </span>
                    {againstPage < 1.6 && (
                        <span className="flex items-center gap-1.5 text-xs text-amber-700 dark:text-amber-400">
                            <TriangleAlert className="size-4" aria-hidden />
                            {t('manage.accent_too_light')}
                        </span>
                    )}
                </div>
            )}
            <InputError
                message={
                    value !== '' && !valid ? t('manage.accent_invalid') : error
                }
            />
        </div>
    );
}
