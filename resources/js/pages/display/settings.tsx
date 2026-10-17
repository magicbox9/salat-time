import { useForm } from '@inertiajs/react';
import { MonitorPlay } from 'lucide-react';
import type { ManagedMessage } from '@/components/display/settings/message-form';
import { MediaSection } from '@/components/display/settings/media-section';
import { MessagesEditor } from '@/components/display/settings/messages-editor';
import { PreviewFrame } from '@/components/display/settings/preview-frame';
import { SaveBar } from '@/components/display/settings/save-bar';
import { ScreenLink } from '@/components/display/settings/screen-link';
import { SettingsEditor } from '@/components/display/settings/settings-editor';
import type {
    AdhanTrack,
    DisplayOptions,
    DisplayPayload,
    DisplaySettings,
} from '@/components/display/types';
import { ManageHeader } from '@/components/manage/manage-header';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import type { MosqueSummary } from '@/types/mosque';

type Props = {
    mosque: MosqueSummary;
    settings: DisplaySettings;
    options: DisplayOptions;
    messages: ManagedMessage[];
    payload: DisplayPayload;
    backgroundUrl: string | null;
    ownAdhan: AdhanTrack | null;
    screenUrl: string;
};

/**
 * GET /manage/{slug}/display — the mosque's screen: how it looks, how a
 * prayer unfolds on it, what it rotates through, the adhan, its messages —
 * with a live preview of the unsaved settings.
 */
export default function DisplaySettingsPage({
    mosque,
    settings,
    options,
    messages,
    payload,
    backgroundUrl,
    ownAdhan,
    screenUrl,
}: Props) {
    const t = useT();
    const form = useForm<DisplaySettings>(settings);
    const errors = form.errors as Partial<Record<string, string>>;
    const save = () =>
        form.put(`/manage/${mosque.slug}/display`, {
            preserveScroll: true,
            onSuccess: () => form.setDefaults(),
        });

    return (
        <div className="mx-auto max-w-7xl space-y-6">
            <ManageHeader
                mosque={mosque}
                title={t('display.settings_title')}
                description={t('display.settings_intro')}
                actions={
                    <Button asChild size="sm">
                        <a href={screenUrl} target="_blank" rel="noopener">
                            <MonitorPlay className="size-4" />
                            {t('display.open_screen')}
                        </a>
                    </Button>
                }
            />

            <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] xl:grid-cols-[minmax(0,1.1fr)_minmax(0,1fr)]">
                <aside className="space-y-6 lg:sticky lg:top-6 lg:self-start">
                    <PreviewFrame payload={payload} settings={form.data} />
                    <ScreenLink url={screenUrl} />
                </aside>

                <div className="min-w-0 space-y-6">
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
                        catalog={payload.catalog}
                        scope="mosque"
                    />
                    <MediaSection
                        slug={mosque.slug}
                        backgroundUrl={backgroundUrl}
                        ownAdhan={ownAdhan}
                        maxBackgroundKb={options.max_background_kb}
                        maxAdhanKb={options.max_adhan_kb}
                    />
                    <MessagesEditor
                        slug={mosque.slug}
                        timezone={mosque.timezone}
                        messages={messages}
                        max={options.max_messages}
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
            />
        </div>
    );
}
