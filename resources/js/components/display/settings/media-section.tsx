import { router } from '@inertiajs/react';
import { ImagePlus, Music, Trash2, Upload } from 'lucide-react';
import { useRef, useState } from 'react';
import InputError from '@/components/input-error';
import { Button } from '@/components/ui/button';
import { Spinner } from '@/components/ui/spinner';
import { useT } from '@/lib/i18n';
import type { AdhanTrack } from '../types';
import { Section } from './controls';

type Props = {
    slug: string;
    backgroundUrl: string | null;
    ownAdhan: AdhanTrack | null;
    maxBackgroundKb: number;
    maxAdhanKb: number;
};

/** The mosque's own background picture and adhan recording (sent at once, apart from the form). */
export function MediaSection({
    slug,
    backgroundUrl,
    ownAdhan,
    maxBackgroundKb,
    maxAdhanKb,
}: Props) {
    const t = useT();

    return (
        <Section
            id="media"
            title={t('display.section_media')}
            description={t('display.section_media_hint')}
            icon={ImagePlus}
        >
            <UploadField
                field="background"
                url={`/manage/${slug}/display/background`}
                accept="image/jpeg,image/png,image/webp"
                maxKb={maxBackgroundKb}
                label={t('display.background')}
                hint={t('display.background_hint', {
                    mb: Math.round(maxBackgroundKb / 1024),
                })}
                current={
                    backgroundUrl ? (
                        <img
                            src={backgroundUrl}
                            alt=""
                            className="h-20 w-36 rounded-lg object-cover ring-1 ring-border"
                        />
                    ) : null
                }
            />
            <UploadField
                field="adhan"
                url={`/manage/${slug}/display/adhan`}
                accept="audio/mpeg,.mp3"
                maxKb={maxAdhanKb}
                label={t('display.own_adhan')}
                hint={t('display.own_adhan_hint', {
                    mb: Math.round(maxAdhanKb / 1024),
                })}
                current={
                    ownAdhan ? (
                        <audio
                            controls
                            preload="none"
                            src={ownAdhan.url}
                            className="h-10 w-full max-w-xs"
                        />
                    ) : null
                }
            />
        </Section>
    );
}

function UploadField({
    field,
    url,
    accept,
    maxKb,
    label,
    hint,
    current,
}: {
    field: 'background' | 'adhan';
    url: string;
    accept: string;
    maxKb: number;
    label: string;
    hint: string;
    current: React.ReactNode;
}) {
    const t = useT();
    const input = useRef<HTMLInputElement>(null);
    const [busy, setBusy] = useState(false);
    const [error, setError] = useState<string | undefined>();
    const Icon = field === 'background' ? ImagePlus : Music;

    const send = (file: File) => {
        if (file.size > maxKb * 1024) {
            setError(
                t('display.upload_too_big', { mb: Math.round(maxKb / 1024) }),
            );

            return;
        }

        setError(undefined);
        router.post(
            url,
            { [field]: file },
            {
                forceFormData: true,
                preserveScroll: true,
                onStart: () => setBusy(true),
                onFinish: () => {
                    setBusy(false);

                    if (input.current) {
                        input.current.value = '';
                    }
                },
                onError: (errors) =>
                    setError(errors[field] ?? Object.values(errors)[0]),
            },
        );
    };

    const remove = () =>
        router.delete(url, {
            preserveScroll: true,
            onStart: () => setBusy(true),
            onFinish: () => setBusy(false),
        });

    return (
        <div className="grid gap-2">
            <span className="text-sm font-medium">{label}</span>
            <div className="flex flex-wrap items-center gap-3">
                {current}
                <input
                    ref={input}
                    type="file"
                    accept={accept}
                    className="sr-only"
                    tabIndex={-1}
                    aria-hidden
                    onChange={(event) =>
                        event.target.files?.[0] && send(event.target.files[0])
                    }
                />
                <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    disabled={busy}
                    onClick={() => input.current?.click()}
                >
                    {busy ? (
                        <Spinner />
                    ) : current ? (
                        <Upload className="size-4" />
                    ) : (
                        <Icon className="size-4" />
                    )}
                    {current ? t('display.replace') : t('display.upload')}
                </Button>
                {current && (
                    <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        disabled={busy}
                        onClick={remove}
                        className="text-destructive hover:text-destructive"
                    >
                        <Trash2 className="size-4" />
                        {t('display.remove')}
                    </Button>
                )}
            </div>
            {!error && <p className="text-xs text-muted-foreground">{hint}</p>}
            <InputError message={error} />
        </div>
    );
}
