import { Link } from '@inertiajs/react';
import { EyeOff, PencilLine } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';

/** Shown to managers on a draft or scheduled post / unpublished page: the public cannot see it. */
export function PreviewNotice({
    message,
    editUrl,
}: {
    message: string;
    editUrl: string;
}) {
    const t = useT();

    return (
        <div
            role="status"
            className="flex flex-wrap items-center gap-3 rounded-2xl border border-gold/60 bg-gold/10 px-4 py-3 text-sm"
        >
            <EyeOff className="size-4 shrink-0 text-gold" aria-hidden />
            <p className="min-w-0 flex-1">
                <span className="font-semibold">{t('mosquesite.preview')}</span>{' '}
                · {message}
            </p>
            <Button asChild size="sm" variant="outline">
                <Link href={editUrl}>
                    <PencilLine className="size-4" aria-hidden />
                    {t('manage.edit')}
                </Link>
            </Button>
        </div>
    );
}
