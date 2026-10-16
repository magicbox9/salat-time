import { router } from '@inertiajs/react';
import { Check, ChevronDown, SlidersHorizontal } from 'lucide-react';
import { useState } from 'react';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import {
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuSeparator,
    DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { deviceTimezone, firstError, STATUS_STYLE } from './tracker-utils';
import type { LogStatus, TrackedPrayer } from './types';
import { STATUSES } from './types';

type Props = {
    date: string;
    prayer: TrackedPrayer;
    suggested: LogStatus;
    onDetails: () => void;
};

/**
 * One tap logs the suggested status (at home, alone); the menu offers the other
 * statuses and the full form (place, congregation).
 */
export function QuickCheckIn({ date, prayer, suggested, onDetails }: Props) {
    const t = useT();
    const [busy, setBusy] = useState(false);

    const log = (status: LogStatus) => {
        router.post(
            '/prayers/logs',
            {
                prayer_date: date,
                prayer,
                status,
                place: 'home',
                in_congregation: false,
                tz: deviceTimezone() ?? '',
            },
            {
                preserveScroll: true,
                onStart: () => setBusy(true),
                onFinish: () => setBusy(false),
                // The row has no form: show why the check-in was refused.
                onError: (errors) => {
                    const message = firstError(errors);

                    if (message) {
                        toast.error(message);
                    }
                },
            },
        );
    };

    return (
        <div className="flex items-center">
            <Button
                size="sm"
                className="rounded-e-none"
                onClick={() => log(suggested)}
                disabled={busy}
            >
                <Check className="size-4" />
                {t(`prayers.quick_${suggested}`)}
            </Button>
            {/* Not modal: the details dialog can open from the menu without locking the page. */}
            <DropdownMenu modal={false}>
                <DropdownMenuTrigger asChild>
                    <Button
                        size="sm"
                        className="rounded-s-none border-s border-primary-foreground/25 px-2"
                        disabled={busy}
                        aria-label={t('prayers.action_more')}
                    >
                        <ChevronDown className="size-4" />
                    </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end" className="min-w-48">
                    {STATUSES.filter((status) => status !== suggested).map(
                        (status) => (
                            <DropdownMenuItem
                                key={status}
                                onSelect={() => log(status)}
                            >
                                <span
                                    className={cn(
                                        'size-2.5 rounded-full',
                                        STATUS_STYLE[status].dot,
                                    )}
                                />
                                {t(`prayers.quick_${status}`)}
                            </DropdownMenuItem>
                        ),
                    )}
                    <DropdownMenuSeparator />
                    <DropdownMenuItem onSelect={onDetails}>
                        <SlidersHorizontal className="size-4" />
                        {t('prayers.action_details')}
                    </DropdownMenuItem>
                </DropdownMenuContent>
            </DropdownMenu>
        </div>
    );
}
