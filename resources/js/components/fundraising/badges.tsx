import {
    Building2,
    Coins,
    GraduationCap,
    HandHeart,
    Lightbulb,
    UtensilsCrossed,
} from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import type { CampaignKind, CampaignState, DonationStatus } from './types';

export const KIND_ICONS: Record<CampaignKind, LucideIcon> = {
    building: Building2,
    zakat: Coins,
    sadaqa: HandHeart,
    iftar: UtensilsCrossed,
    education: GraduationCap,
    project: Lightbulb,
};

/** "Building", "Zakat"… with its icon. `onImage` for the glassy badge over a cover. */
export function KindBadge({
    kind,
    onImage = false,
    className,
}: {
    kind: CampaignKind;
    onImage?: boolean;
    className?: string;
}) {
    const t = useT();
    const Icon = KIND_ICONS[kind] ?? Lightbulb;

    return (
        <span
            className={cn(
                'inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium',
                onImage
                    ? 'bg-black/35 text-white ring-1 ring-white/25 backdrop-blur-md'
                    : 'bg-primary/10 text-primary',
                className,
            )}
        >
            <Icon className="size-3.5" aria-hidden />
            {t(`fundraising.kind_${kind}`)}
        </span>
    );
}

const STATE_STYLES: Record<CampaignState, string> = {
    active: 'bg-emerald-500/15 text-emerald-800 dark:text-emerald-300',
    upcoming: 'bg-sky-500/15 text-sky-800 dark:text-sky-300',
    ended: 'bg-muted text-muted-foreground',
    completed: 'bg-gold/25 text-amber-900 dark:text-gold',
    closed: 'bg-muted text-muted-foreground',
    draft: 'bg-muted text-muted-foreground',
    pending: 'bg-amber-500/15 text-amber-900 dark:text-amber-300',
    rejected: 'bg-red-500/15 text-red-800 dark:text-red-300',
};

export function StateBadge({
    state,
    className,
}: {
    state: CampaignState;
    className?: string;
}) {
    const t = useT();

    return (
        <span
            className={cn(
                'inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium whitespace-nowrap',
                STATE_STYLES[state],
                className,
            )}
        >
            {t(`fundraising.state_${state}`)}
        </span>
    );
}

const DONATION_STYLES: Record<DonationStatus, string> = {
    pending: 'bg-amber-500/15 text-amber-900 dark:text-amber-300',
    completed: 'bg-emerald-500/15 text-emerald-800 dark:text-emerald-300',
    cancelled: 'bg-muted text-muted-foreground',
    failed: 'bg-red-500/15 text-red-800 dark:text-red-300',
    refunded: 'bg-muted text-muted-foreground',
};

export function DonationStatusBadge({ status }: { status: DonationStatus }) {
    const t = useT();

    return (
        <span
            className={cn(
                'inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium whitespace-nowrap',
                DONATION_STYLES[status],
            )}
        >
            {t(`fundraising.donation_${status}`)}
        </span>
    );
}
