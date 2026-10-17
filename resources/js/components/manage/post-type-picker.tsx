import { CalendarDays, Flower2, Megaphone, Newspaper } from 'lucide-react';
import type { PostType } from '@/components/mosque/types';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';

const ICONS: Record<PostType, typeof Newspaper> = {
    news: Newspaper,
    event: CalendarDays,
    announcement: Megaphone,
    janaza: Flower2,
};

type Props = {
    types: PostType[];
    value: PostType;
    onChange: (type: PostType) => void;
};

/** The four kinds of post, as selectable cards. */
export function PostTypePicker({ types, value, onChange }: Props) {
    const t = useT();

    return (
        <div
            role="radiogroup"
            aria-label={t('manage.post_kind')}
            className="grid grid-cols-2 gap-2 sm:grid-cols-4 xl:grid-cols-2"
        >
            {types.map((type) => {
                const Icon = ICONS[type] ?? Newspaper;
                const active = type === value;

                return (
                    <button
                        key={type}
                        type="button"
                        role="radio"
                        aria-checked={active}
                        onClick={() => onChange(type)}
                        className={cn(
                            'flex flex-col items-start gap-1 rounded-xl border px-3 py-3 text-start transition-colors outline-none focus-visible:ring-2 focus-visible:ring-ring/60',
                            active
                                ? 'border-primary bg-primary/5 ring-1 ring-primary/40'
                                : 'hover:bg-accent/60',
                        )}
                    >
                        <Icon
                            className={cn(
                                'size-5',
                                active
                                    ? 'text-primary'
                                    : 'text-muted-foreground',
                            )}
                        />
                        <span className="text-sm font-medium">
                            {t(`mosque.type_${type}`)}
                        </span>
                        <span className="text-xs text-muted-foreground">
                            {t(`manage.type_${type}_hint`)}
                        </span>
                    </button>
                );
            })}
        </div>
    );
}
