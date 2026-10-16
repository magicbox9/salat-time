import { usePage } from '@inertiajs/react';
import {
    AArrowDown,
    AArrowUp,
    Headphones,
    Languages,
    Pause,
    Play,
    Settings2,
} from 'lucide-react';
import { useState } from 'react';
import type { FormEvent } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from '@/components/ui/select';
import {
    Sheet,
    SheetContent,
    SheetHeader,
    SheetTitle,
    SheetTrigger,
} from '@/components/ui/sheet';
import { useT } from '@/lib/i18n';
import type { Reciter, TranslationOption } from './types';

export type ReaderSettings = {
    reciters: Reciter[];
    reciter: string;
    onReciter: (id: string) => void;
    translations: TranslationOption[];
    translationCode: string;
    onTranslation: (code: string) => void;
    ayahCount: number;
    onGoTo: (ayah: number) => void;
};

type Props = ReaderSettings & {
    playing: boolean;
    /** A recitation is paused: the main button resumes it. */
    paused: boolean;
    onPlay: () => void;
    onPause: () => void;
    canShrink: boolean;
    canGrow: boolean;
    onShrink: () => void;
    onGrow: () => void;
};

function ReciterSelect({ reciters, reciter, onReciter }: ReaderSettings) {
    const t = useT();
    const { locale } = usePage().props;

    return (
        <Select value={reciter} onValueChange={onReciter}>
            <SelectTrigger
                className="w-full sm:w-52"
                aria-label={t('quran.reciter')}
            >
                <Headphones className="size-4 text-muted-foreground" />
                <SelectValue />
            </SelectTrigger>
            <SelectContent>
                {reciters.map((r) => (
                    <SelectItem key={r.id} value={r.id}>
                        {locale === 'ar' ? r.name_ar : r.name}
                    </SelectItem>
                ))}
            </SelectContent>
        </Select>
    );
}

function TranslationSelect({
    translations,
    translationCode,
    onTranslation,
}: ReaderSettings) {
    const t = useT();

    return (
        <Select value={translationCode} onValueChange={onTranslation}>
            <SelectTrigger
                className="w-full sm:w-48"
                aria-label={t('quran.translation')}
            >
                <Languages className="size-4 text-muted-foreground" />
                <SelectValue />
            </SelectTrigger>
            <SelectContent>
                <SelectItem value="none">
                    {t('quran.translation_none')}
                </SelectItem>
                {translations.map((option) => (
                    <SelectItem key={option.code} value={option.code}>
                        {option.translator} ({option.language.toUpperCase()})
                    </SelectItem>
                ))}
            </SelectContent>
        </Select>
    );
}

function GoToAyah({ ayahCount, onGoTo }: ReaderSettings) {
    const t = useT();
    const [value, setValue] = useState('');

    const submit = (event: FormEvent) => {
        event.preventDefault();
        const ayah = Number.parseInt(value, 10);
        if (ayah >= 1 && ayah <= ayahCount) {
            onGoTo(ayah);
            setValue('');
        }
    };

    return (
        <form onSubmit={submit} className="flex items-center gap-2">
            <Input
                type="number"
                inputMode="numeric"
                min={1}
                max={ayahCount}
                value={value}
                onChange={(event) => setValue(event.target.value)}
                placeholder={t('quran.go_to_ayah')}
                aria-label={t('quran.go_to_ayah')}
                className="w-full sm:w-36"
                dir="ltr"
            />
            <Button type="submit" variant="outline">
                {t('quran.go')}
            </Button>
        </form>
    );
}

/** Sticky reading bar: recitation, text size, and the reading options. */
export function ReaderToolbar(props: Props) {
    const t = useT();
    const [open, setOpen] = useState(false);
    const {
        playing,
        paused,
        onPlay,
        onPause,
        canShrink,
        canGrow,
        onShrink,
        onGrow,
    } = props;
    const sheetProps = {
        ...props,
        onGoTo: (ayah: number) => {
            setOpen(false);
            props.onGoTo(ayah);
        },
    };

    return (
        <div className="sticky top-16 z-30 -mx-1 flex items-center gap-2 rounded-xl border bg-background/90 p-2 shadow-sm backdrop-blur">
            <Button onClick={playing ? onPause : onPlay} className="shrink-0">
                {playing ? <Pause /> : <Play />}
                {playing
                    ? t('quran.pause')
                    : paused
                      ? t('quran.resume')
                      : t('quran.play_surah')}
            </Button>

            <div className="hidden items-center gap-2 lg:flex">
                <ReciterSelect {...props} />
                <TranslationSelect {...props} />
            </div>

            <div className="ms-auto flex items-center gap-1">
                <Button
                    variant="ghost"
                    size="icon"
                    onClick={onShrink}
                    disabled={!canShrink}
                    aria-label={t('quran.smaller')}
                    title={t('quran.smaller')}
                >
                    <AArrowDown />
                </Button>
                <Button
                    variant="ghost"
                    size="icon"
                    onClick={onGrow}
                    disabled={!canGrow}
                    aria-label={t('quran.larger')}
                    title={t('quran.larger')}
                >
                    <AArrowUp />
                </Button>
                <Sheet open={open} onOpenChange={setOpen}>
                    <SheetTrigger asChild>
                        <Button
                            variant="outline"
                            size="icon"
                            aria-label={t('quran.settings')}
                            title={t('quran.settings')}
                        >
                            <Settings2 />
                        </Button>
                    </SheetTrigger>
                    <SheetContent
                        side="bottom"
                        className="mx-auto max-w-lg rounded-t-2xl"
                    >
                        <SheetHeader>
                            <SheetTitle>{t('quran.settings')}</SheetTitle>
                        </SheetHeader>
                        <div className="space-y-5 px-4 pb-6">
                            <div className="space-y-2">
                                <Label>{t('quran.reciter')}</Label>
                                <ReciterSelect {...sheetProps} />
                            </div>
                            <div className="space-y-2">
                                <Label>{t('quran.translation')}</Label>
                                <TranslationSelect {...sheetProps} />
                                <p className="text-xs text-muted-foreground">
                                    {t('quran.translation_hafs_only')}
                                </p>
                            </div>
                            <div className="space-y-2">
                                <Label>{t('quran.go_to_ayah')}</Label>
                                <GoToAyah {...sheetProps} />
                            </div>
                        </div>
                    </SheetContent>
                </Sheet>
            </div>
        </div>
    );
}
