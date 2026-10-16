import { CalendarDays, Megaphone, Newspaper, Flower2 } from 'lucide-react';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import type { PostType } from './types';

const STYLES: Record<PostType, { icon: typeof Newspaper; className: string }> =
    {
        news: { icon: Newspaper, className: 'bg-primary/10 text-primary' },
        event: {
            icon: CalendarDays,
            className: 'bg-sky-500/10 text-sky-700 dark:text-sky-300',
        },
        announcement: {
            icon: Megaphone,
            className: 'bg-gold/20 text-foreground',
        },
        janaza: { icon: Flower2, className: 'bg-muted text-muted-foreground' },
    };

export function PostTypeBadge({
    type,
    className,
}: {
    type: PostType;
    className?: string;
}) {
    const t = useT();
    const style = STYLES[type] ?? STYLES.news;

    return (
        <span
            className={cn(
                'inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-medium',
                style.className,
                className,
            )}
        >
            <style.icon className="size-3.5" />
            {t(`mosque.type_${type}`)}
        </span>
    );
}

/** "3 hours ago", in the visitor's language. */
export function timeAgo(
    iso: string,
    locale: string,
    now: number = Date.now(),
): string {
    const seconds = Math.round((new Date(iso).getTime() - now) / 1000);
    const format = new Intl.RelativeTimeFormat(
        locale === 'ar' ? 'ar-u-nu-latn' : locale,
        { numeric: 'auto' },
    );
    const units: [Intl.RelativeTimeFormatUnit, number][] = [
        ['year', 31_536_000],
        ['month', 2_592_000],
        ['week', 604_800],
        ['day', 86_400],
        ['hour', 3_600],
        ['minute', 60],
    ];

    for (const [unit, size] of units) {
        if (Math.abs(seconds) >= size) {
            return format.format(Math.round(seconds / size), unit);
        }
    }

    return format.format(0, 'minute');
}
