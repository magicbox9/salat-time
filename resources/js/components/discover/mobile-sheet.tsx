import { ChevronDown } from 'lucide-react';
import type { ReactNode } from 'react';
import { useState } from 'react';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';

type Props = {
    title: string;
    children: ReactNode;
};

/** Phones: the results sit in a sheet at the bottom that can be folded to see the map. */
export function MobileSheet({ title, children }: Props) {
    const t = useT();
    const [open, setOpen] = useState(true);

    return (
        <div className="rounded-t-2xl border border-b-0 bg-background/95 shadow-[0_-8px_30px_rgb(0_0_0/0.18)] backdrop-blur-xl">
            <button
                type="button"
                onClick={() => setOpen((v) => !v)}
                aria-expanded={open}
                className="flex w-full flex-col items-center gap-1 px-4 pt-2 pb-2"
            >
                <span
                    aria-hidden
                    className="h-1 w-10 rounded-full bg-muted-foreground/30"
                />
                <span className="flex w-full items-center justify-between gap-2 text-sm font-medium">
                    <span className="truncate">{title}</span>
                    <span className="flex shrink-0 items-center gap-1 text-xs text-muted-foreground">
                        {open
                            ? t('discover.show_map')
                            : t('discover.show_list')}
                        <ChevronDown
                            className={cn(
                                'size-4 transition-transform',
                                !open && 'rotate-180',
                            )}
                            aria-hidden
                        />
                    </span>
                </span>
            </button>
            {open && (
                <div className="flex max-h-[42svh] min-h-0 flex-col px-3 pb-[max(0.75rem,env(safe-area-inset-bottom))]">
                    {children}
                </div>
            )}
        </div>
    );
}
