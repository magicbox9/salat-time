import type { LucideIcon } from 'lucide-react';
import {
    AlignJustify,
    GitCommitVertical,
    LayoutGrid,
    Orbit,
    Rainbow,
} from 'lucide-react';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import type { HubStyle } from '../types';
import { HUB_STYLES } from '../types';

export const STYLE_ICON: Record<HubStyle, LucideIcon> = {
    cards: LayoutGrid,
    timeline: GitCommitVertical,
    arc: Rainbow,
    dial: Orbit,
    minimal: AlignJustify,
};

/** The five display styles as large choice tiles. */
export function StylePicker({
    value,
    onChange,
}: {
    value: HubStyle;
    onChange: (style: HubStyle) => void;
}) {
    const t = useT();

    return (
        <div
            role="radiogroup"
            aria-label={t('hub.custom_style')}
            className="grid grid-cols-2 gap-2"
        >
            {HUB_STYLES.map((style) => {
                const Icon = STYLE_ICON[style];
                const selected = value === style;

                return (
                    <button
                        key={style}
                        type="button"
                        role="radio"
                        aria-checked={selected}
                        onClick={() => onChange(style)}
                        className={cn(
                            'flex flex-col items-start gap-1.5 rounded-xl border p-3 text-start transition-colors focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-none',
                            selected
                                ? 'border-primary bg-primary/8 ring-1 ring-primary'
                                : 'hover:border-primary/40 hover:bg-accent/50',
                            style === 'minimal' && 'col-span-2',
                        )}
                    >
                        <Icon
                            aria-hidden
                            className={cn(
                                'size-5',
                                selected
                                    ? 'text-primary'
                                    : 'text-muted-foreground',
                            )}
                        />
                        <span className="text-sm font-medium">
                            {t(`hub.style_${style}`)}
                        </span>
                        <span className="text-xs leading-snug text-muted-foreground">
                            {t(`hub.style_${style}_hint`)}
                        </span>
                    </button>
                );
            })}
        </div>
    );
}
