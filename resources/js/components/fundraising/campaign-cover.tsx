import { Arabesque } from '@/components/mosque/arabesque';
import { cn } from '@/lib/utils';

/** The campaign's picture, or the green-and-gold tile pattern when it has none. */
export function CampaignCover({
    url,
    className,
    eager = false,
    children,
}: {
    url: string | null;
    className?: string;
    eager?: boolean;
    children?: React.ReactNode;
}) {
    return (
        <div className={cn('relative overflow-hidden bg-primary', className)}>
            {url ? (
                <img
                    src={url}
                    alt=""
                    className="h-full w-full object-cover"
                    loading={eager ? 'eager' : 'lazy'}
                    decoding="async"
                />
            ) : (
                <Arabesque />
            )}
            <div className="pointer-events-none absolute inset-0 bg-gradient-to-t from-black/45 via-black/5 to-transparent" />
            {children}
        </div>
    );
}
