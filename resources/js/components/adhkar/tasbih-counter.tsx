import { Check } from 'lucide-react';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';

type Props = {
    count: number;
    total: number;
    onTap: () => void;
    className?: string;
};

const RADIUS = 34;
const CIRCUMFERENCE = 2 * Math.PI * RADIUS;

/** A tasbih: each tap fills the ring a little more until the dhikr is done. */
export function TasbihCounter({ count, total, onTap, className }: Props) {
    const t = useT();
    const done = count >= total;
    const ratio = Math.min(1, count / total);

    return (
        <button
            type="button"
            onClick={onTap}
            disabled={done}
            aria-label={`${t('adhkar.tap_to_count')} — ${t('adhkar.counted', { done: count, total })}`}
            className={cn(
                'group relative grid size-20 shrink-0 touch-manipulation place-items-center rounded-full transition-transform select-none focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-none enabled:active:scale-95',
                done ? 'bg-gold/15' : 'bg-primary/5 hover:bg-primary/10',
                className,
            )}
        >
            <svg
                viewBox="0 0 80 80"
                className="absolute inset-0 -rotate-90"
                aria-hidden
            >
                <circle
                    cx="40"
                    cy="40"
                    r={RADIUS}
                    fill="none"
                    strokeWidth="6"
                    className="stroke-muted"
                />
                <circle
                    cx="40"
                    cy="40"
                    r={RADIUS}
                    fill="none"
                    strokeWidth="6"
                    strokeLinecap="round"
                    strokeDasharray={CIRCUMFERENCE}
                    strokeDashoffset={CIRCUMFERENCE * (1 - ratio)}
                    className={cn(
                        'transition-[stroke-dashoffset] duration-300',
                        done ? 'stroke-gold' : 'stroke-primary',
                    )}
                />
            </svg>
            {done ? (
                <Check className="relative size-7 text-gold" strokeWidth={3} />
            ) : (
                <span
                    className="relative flex flex-col items-center leading-none"
                    dir="ltr"
                >
                    <span className="text-lg font-semibold tabular-nums">
                        {count}
                    </span>
                    <span className="mt-0.5 text-[10px] text-muted-foreground tabular-nums">
                        / {total}
                    </span>
                </span>
            )}
        </button>
    );
}
