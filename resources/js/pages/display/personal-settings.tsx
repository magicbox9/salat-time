import { Head, Link, useForm } from '@inertiajs/react';
import { Compass, MapPin, MonitorPlay } from 'lucide-react';
import { useEffect, useRef } from 'react';
import { toast } from 'sonner';
import {
    PERSONAL_MUTE_SLUG,
    clearDeviceMute,
} from '@/components/display/hooks/use-device-mute';
import {
    mergeSettings,
    readGuestSettings,
    writeGuestSettings,
} from '@/components/display/lib/settings';
import { PreviewFrame } from '@/components/display/settings/preview-frame';
import { SaveBar } from '@/components/display/settings/save-bar';
import { SettingsEditor } from '@/components/display/settings/settings-editor';
import type {
    DisplayOptions,
    DisplayPayload,
    DisplaySettings,
} from '@/components/display/types';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import type { MosqueSummary } from '@/types/mosque';

type Props = {
    mosque: MosqueSummary | null;
    payload: DisplayPayload | null;
    /** The account's saved choices (null for guests, or before any are saved). */
    settings: DisplaySettings | null;
    options: DisplayOptions;
    signedIn: boolean;
};

/**
 * GET /display/settings — a person's own screen at /display. Saved on the
 * account when signed in, in this browser otherwise.
 */
export default function PersonalDisplaySettings({
    mosque,
    payload,
    settings,
    options,
    signedIn,
}: Props) {
    const t = useT();
    const form = useForm<DisplaySettings>(settings ?? options.defaults);
    const errors = form.errors as Partial<Record<string, string>>;
    // The saved "mute" choice: when it changes, the screen's own switch on this device yields to it.
    const savedMuted = useRef(settings?.muted ?? options.defaults.muted);
    const mutedSaved = () => {
        if (form.data.muted !== savedMuted.current) {
            clearDeviceMute(PERSONAL_MUTE_SLUG);
            savedMuted.current = form.data.muted;
        }
    };

    // Guests: their choices live in this browser (read once mounted).
    useEffect(() => {
        if (signedIn) {
            return;
        }

        const stored = mergeSettings(options.defaults, readGuestSettings());
        savedMuted.current = stored.muted;
        form.setDefaults(stored);
        form.setData(stored);
    }, [signedIn]);

    const save = () => {
        if (signedIn) {
            form.put('/display/settings', {
                preserveScroll: true,
                onSuccess: () => {
                    mutedSaved();
                    form.setDefaults();
                },
            });

            return;
        }

        writeGuestSettings(form.data);
        mutedSaved();
        form.setDefaults();
        toast.success(t('display.saved_device'));
    };

    return (
        <div className="mx-auto max-w-7xl space-y-6">
            <Head title={t('display.personal_title')} />
            <header className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
                <div className="space-y-1.5">
                    <h1 className="text-2xl font-semibold tracking-tight sm:text-3xl">
                        {t('display.personal_title')}
                    </h1>
                    <p className="max-w-2xl text-sm text-muted-foreground">
                        {t(
                            signedIn
                                ? 'display.personal_intro'
                                : 'display.personal_intro_guest',
                        )}
                    </p>
                </div>
                <Button asChild>
                    <Link href="/display">
                        <MonitorPlay className="size-4" />
                        {t('display.open_my_screen')}
                    </Link>
                </Button>
            </header>

            {mosque ? (
                <p className="flex flex-wrap items-center gap-x-2 gap-y-1 rounded-xl bg-muted px-4 py-3 text-sm">
                    <MapPin className="size-4 text-primary" aria-hidden />
                    <span className="text-muted-foreground">
                        {t('display.personal_mosque')}
                    </span>
                    <Link
                        href={`/mosques/${mosque.slug}`}
                        className="font-medium hover:underline"
                    >
                        {mosque.name}
                    </Link>
                    <Link
                        href="/explore"
                        className="ms-auto text-primary hover:underline"
                    >
                        {t('display.change_mosque')}
                    </Link>
                </p>
            ) : (
                <div className="flex flex-col items-start gap-3 rounded-2xl border border-dashed p-5 sm:flex-row sm:items-center">
                    <p className="flex-1 text-sm text-muted-foreground">
                        {t('display.choose_body')}
                    </p>
                    <Button asChild variant="outline">
                        <Link href="/explore">
                            <Compass className="size-4" />
                            {t('display.choose_action')}
                        </Link>
                    </Button>
                </div>
            )}

            <div
                className={
                    payload
                        ? 'grid gap-6 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]'
                        : 'mx-auto max-w-3xl'
                }
            >
                {payload && (
                    <aside className="lg:sticky lg:top-6 lg:self-start">
                        <PreviewFrame payload={payload} settings={form.data} />
                    </aside>
                )}
                <div className="min-w-0">
                    <SettingsEditor
                        value={form.data}
                        onChange={(patch) =>
                            form.setData((current) => ({
                                ...current,
                                ...patch,
                            }))
                        }
                        options={options}
                        errors={errors}
                        payload={payload}
                        catalog={payload?.catalog ?? []}
                        scope="personal"
                    />
                </div>
            </div>

            <SaveBar
                dirty={form.isDirty}
                processing={form.processing}
                hasErrors={Object.keys(errors).length > 0}
                onSave={save}
                onReset={() => {
                    form.reset();
                    form.clearErrors();
                }}
                savedLabel={signedIn ? undefined : t('display.saved_on_device')}
            />
        </div>
    );
}
