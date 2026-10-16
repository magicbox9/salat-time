import { useForm, usePage } from '@inertiajs/react';
import { Building2, Undo2, Users } from 'lucide-react';
import { useEffect, useState } from 'react';
import InputError from '@/components/input-error';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group';
import { intlLocale, useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import type { MosqueSummary } from '@/types/mosque';
import {
    deviceTimezone,
    formatDay,
    removeLog,
    STATUS_STYLE,
} from './tracker-utils';
import type { CheckInTarget, LogPlace, LogStatus } from './types';
import { PLACES, STATUSES } from './types';

type Props = {
    target: CheckInTarget | null;
    today: string;
    mosque: MosqueSummary | null;
    onClose: () => void;
};

type FormData = {
    prayer_date: string;
    prayer: string;
    status: LogStatus;
    place: LogPlace;
    in_congregation: boolean;
    tz: string;
};

/** Log one prayer (or change / undo it): status, place and congregation. */
export function CheckInDialog({ target, today, mosque, onClose }: Props) {
    const t = useT();
    const { locale } = usePage().props;
    const [removing, setRemoving] = useState(false);
    const form = useForm<FormData>({
        prayer_date: '',
        prayer: '',
        status: 'on_time',
        place: 'home',
        in_congregation: false,
        tz: '',
    });

    useEffect(() => {
        if (!target) {
            return;
        }

        form.setData({
            prayer_date: target.date,
            prayer: target.prayer,
            status: target.log?.status ?? target.suggested,
            place: target.log?.place ?? 'home',
            in_congregation: target.log?.in_congregation ?? false,
            tz: deviceTimezone() ?? '',
        });
        form.clearErrors();
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [target]);

    const missed = form.data.status === 'missed';
    const dayLabel =
        target?.date === today
            ? t('site.today')
            : target
              ? formatDay(target.date, intlLocale(locale), {
                    weekday: 'long',
                    day: 'numeric',
                    month: 'long',
                })
              : '';

    const submit = (event: React.FormEvent) => {
        event.preventDefault();
        form.post('/prayers/logs', {
            preserveScroll: true,
            onSuccess: onClose,
        });
    };

    return (
        <Dialog
            open={target !== null}
            onOpenChange={(open) => !open && onClose()}
        >
            <DialogContent className="sm:max-w-md">
                <form onSubmit={submit} className="space-y-5">
                    <DialogHeader>
                        <DialogTitle>
                            {target ? t(`site.prayer_${target.prayer}`) : ''} ·{' '}
                            {dayLabel}
                        </DialogTitle>
                        <DialogDescription>
                            {t('prayers.dialog_intro')}
                        </DialogDescription>
                    </DialogHeader>

                    <fieldset className="space-y-2">
                        <legend className="text-sm font-medium">
                            {t('prayers.field_status')}
                        </legend>
                        <ToggleGroup
                            type="single"
                            variant="outline"
                            value={form.data.status}
                            onValueChange={(value) =>
                                value &&
                                form.setData('status', value as LogStatus)
                            }
                            className="grid w-full grid-cols-2 gap-2 sm:grid-cols-4"
                        >
                            {STATUSES.map((status) => (
                                <ToggleGroupItem
                                    key={status}
                                    value={status}
                                    className="h-auto justify-start gap-2 rounded-lg! border! px-3 py-2 data-[state=on]:border-primary data-[state=on]:bg-primary/8"
                                >
                                    <span
                                        className={cn(
                                            'size-2.5 shrink-0 rounded-full',
                                            STATUS_STYLE[status].dot,
                                        )}
                                    />
                                    <span className="text-xs">
                                        {t(`prayers.status_${status}`)}
                                    </span>
                                </ToggleGroupItem>
                            ))}
                        </ToggleGroup>
                        {target &&
                            !target.log &&
                            form.data.status === target.suggested && (
                                <p className="text-xs text-muted-foreground">
                                    {t('prayers.suggested_hint')}
                                </p>
                            )}
                        <InputError
                            message={
                                form.errors.status ??
                                form.errors.prayer_date ??
                                form.errors.prayer
                            }
                        />
                    </fieldset>

                    {!missed && (
                        <>
                            <fieldset className="space-y-2">
                                <legend className="text-sm font-medium">
                                    {t('prayers.field_place')}
                                </legend>
                                <ToggleGroup
                                    type="single"
                                    variant="outline"
                                    value={form.data.place}
                                    onValueChange={(value) =>
                                        value &&
                                        form.setData('place', value as LogPlace)
                                    }
                                    className="grid w-full grid-cols-2 gap-2 sm:grid-cols-4"
                                >
                                    {PLACES.map((place) => (
                                        <ToggleGroupItem
                                            key={place}
                                            value={place}
                                            className="rounded-lg! border! text-xs data-[state=on]:border-primary data-[state=on]:bg-primary/8"
                                        >
                                            {t(`prayers.place_${place}`)}
                                        </ToggleGroupItem>
                                    ))}
                                </ToggleGroup>
                                {form.data.place === 'mosque' && (
                                    <p className="flex items-center gap-1.5 text-xs text-muted-foreground">
                                        <Building2 className="size-3.5 shrink-0" />
                                        {mosque
                                            ? mosque.name
                                            : t('prayers.place_mosque_none')}
                                    </p>
                                )}
                                <InputError message={form.errors.place} />
                            </fieldset>

                            <div className="flex items-center gap-3 rounded-lg border px-3 py-2.5">
                                <Checkbox
                                    id="in_congregation"
                                    checked={form.data.in_congregation}
                                    onCheckedChange={(checked) =>
                                        form.setData(
                                            'in_congregation',
                                            checked === true,
                                        )
                                    }
                                />
                                <Label
                                    htmlFor="in_congregation"
                                    className="flex flex-1 items-center gap-2 font-normal"
                                >
                                    <Users className="size-4 text-muted-foreground" />
                                    {t('prayers.field_congregation')}
                                </Label>
                            </div>
                        </>
                    )}

                    <DialogFooter className="gap-2 sm:justify-between">
                        {target?.log ? (
                            <Button
                                type="button"
                                variant="ghost"
                                className="text-muted-foreground"
                                disabled={removing || form.processing}
                                onClick={() => {
                                    setRemoving(true);
                                    removeLog(target.log!.id, () => {
                                        setRemoving(false);
                                        onClose();
                                    });
                                }}
                            >
                                <Undo2 className="size-4 rtl:-scale-x-100" />
                                {t('prayers.action_undo')}
                            </Button>
                        ) : (
                            <span />
                        )}
                        <Button
                            type="submit"
                            disabled={form.processing || removing}
                        >
                            {target?.log
                                ? t('prayers.action_update')
                                : t('prayers.action_save')}
                        </Button>
                    </DialogFooter>
                </form>
            </DialogContent>
        </Dialog>
    );
}
