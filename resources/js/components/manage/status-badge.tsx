import { CalendarClock, CircleCheck, PencilLine } from 'lucide-react';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';

export type PublishStatus = 'published' | 'scheduled' | 'draft';

const STYLES: Record<
    PublishStatus,
    { icon: typeof PencilLine; className: string }
> = {
    published: {
        icon: CircleCheck,
        className: 'bg-emerald-500/10 text-emerald-800 dark:text-emerald-300',
    },
    scheduled: {
        icon: CalendarClock,
        className: 'bg-sky-500/10 text-sky-800 dark:text-sky-300',
    },
    draft: { icon: PencilLine, className: 'bg-gold/20 text-foreground' },
};

/** Published / scheduled / draft, as a small badge. */
export function StatusBadge({
    status,
    className,
}: {
    status: PublishStatus;
    className?: string;
}) {
    const t = useT();
    const style = STYLES[status];

    return (
        <span
            className={cn(
                'inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium',
                style.className,
                className,
            )}
        >
            <style.icon className="size-3.5" aria-hidden />
            {t(`manage.status_${status}`)}
        </span>
    );
}
