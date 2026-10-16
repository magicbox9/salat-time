import { CircleCheck, CircleX, Clock } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import type { ClaimStatus } from './types';

const STYLES: Record<ClaimStatus, string> = {
    pending: 'border-gold/50 bg-gold/15 text-amber-800 dark:text-gold',
    approved: 'border-primary/30 bg-primary/10 text-primary',
    rejected:
        'border-destructive/30 bg-destructive/10 text-destructive dark:text-red-300',
};

const ICONS = { pending: Clock, approved: CircleCheck, rejected: CircleX };

export function ClaimStatusBadge({
    status,
    className,
}: {
    status: ClaimStatus;
    className?: string;
}) {
    const t = useT();
    const Icon = ICONS[status];

    return (
        <Badge
            variant="outline"
            className={cn('rounded-full px-2.5', STYLES[status], className)}
        >
            <Icon aria-hidden />
            {t(`claims.status_${status}`)}
        </Badge>
    );
}
