import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { KIND_ICONS } from './badges';
import type { CampaignKind } from './types';

/** The kind of campaign as a grid of radio cards (building, zakat, sadaqa…). */
export function KindPicker({
    kinds,
    value,
    onChange,
    disabled = false,
}: {
    kinds: CampaignKind[];
    value: CampaignKind;
    onChange: (kind: CampaignKind) => void;
    disabled?: boolean;
}) {
    const t = useT();

    return (
        <div
            role="radiogroup"
            aria-label={t('fundraising.field_kind')}
            className="grid grid-cols-2 gap-2 sm:grid-cols-3"
        >
            {kinds.map((kind) => {
                const Icon = KIND_ICONS[kind];
                const checked = kind === value;

                return (
                    <button
                        key={kind}
                        type="button"
                        role="radio"
                        aria-checked={checked}
                        disabled={disabled}
                        onClick={() => onChange(kind)}
                        className={cn(
                            'flex items-start gap-3 rounded-xl border p-3 text-start transition-all outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:cursor-not-allowed disabled:opacity-60',
                            checked
                                ? 'border-primary bg-primary/5 ring-1 ring-primary'
                                : 'hover:border-primary/40',
                        )}
                    >
                        <span
                            className={cn(
                                'flex size-9 shrink-0 items-center justify-center rounded-lg',
                                checked
                                    ? 'bg-primary text-primary-foreground'
                                    : 'bg-muted text-muted-foreground',
                            )}
                        >
                            <Icon className="size-4" aria-hidden />
                        </span>
                        <span className="min-w-0">
                            <span className="block text-sm font-semibold">
                                {t(`fundraising.kind_${kind}`)}
                            </span>
                            <span className="block text-xs text-muted-foreground">
                                {t(`fundraising.kind_${kind}_hint`)}
                            </span>
                        </span>
                    </button>
                );
            })}
        </div>
    );
}
