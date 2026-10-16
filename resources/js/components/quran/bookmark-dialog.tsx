import { router, usePage } from '@inertiajs/react';
import { Trash2 } from 'lucide-react';
import { useState } from 'react';
import type { FormEvent } from 'react';
import InputError from '@/components/input-error';
import { Button } from '@/components/ui/button';
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import { useT } from '@/lib/i18n';
import { surahName } from './types';
import type { ReaderBookmark, SurahMeta } from './types';

type Props = {
    surah: SurahMeta;
    bookmark: ReaderBookmark | null;
    onClose: () => void;
};

const VISIT = {
    preserveScroll: true,
    preserveState: true,
    only: ['bookmarks'],
};

/** Edit the note of a bookmarked ayah, or remove the bookmark. */
export function BookmarkDialog({ surah, bookmark, onClose }: Props) {
    return (
        <Dialog
            open={bookmark !== null}
            onOpenChange={(open) => !open && onClose()}
        >
            <DialogContent className="sm:max-w-md">
                {bookmark && (
                    <BookmarkForm
                        key={bookmark.id}
                        surah={surah}
                        bookmark={bookmark}
                        onClose={onClose}
                    />
                )}
            </DialogContent>
        </Dialog>
    );
}

function BookmarkForm({
    surah,
    bookmark,
    onClose,
}: Props & { bookmark: ReaderBookmark }) {
    const t = useT();
    const { locale } = usePage().props;
    const [note, setNote] = useState(bookmark.note ?? '');
    const [busy, setBusy] = useState(false);
    const [error, setError] = useState<string | undefined>();
    const onError = (errors: Record<string, string>) =>
        setError(Object.values(errors)[0]);

    const save = (event: FormEvent) => {
        event.preventDefault();
        setBusy(true);
        setError(undefined);
        router.post(
            '/quran/bookmarks',
            {
                surah: surah.number,
                ayah: bookmark.ayah,
                note: note.trim() === '' ? null : note.trim(),
            },
            {
                ...VISIT,
                onSuccess: onClose,
                onError,
                onFinish: () => setBusy(false),
            },
        );
    };

    const remove = () => {
        setBusy(true);
        setError(undefined);
        router.delete(`/quran/bookmarks/${bookmark.id}`, {
            ...VISIT,
            onSuccess: onClose,
            onError,
            onFinish: () => setBusy(false),
        });
    };

    return (
        <form onSubmit={save} className="space-y-4">
            <DialogHeader>
                <DialogTitle>{t('quran.bookmark')}</DialogTitle>
                <DialogDescription>
                    <span dir="auto">{surahName(surah, locale)}</span>{' '}
                    <span dir="ltr" className="tabular-nums">
                        {surah.number}:{bookmark.ayah}
                    </span>
                </DialogDescription>
            </DialogHeader>
            <div className="space-y-2">
                <Label htmlFor="bookmark-note">
                    {t('quran.bookmark_note')}
                </Label>
                <textarea
                    id="bookmark-note"
                    value={note}
                    onChange={(event) => setNote(event.target.value)}
                    maxLength={500}
                    rows={4}
                    placeholder={t('quran.bookmark_note_placeholder')}
                    aria-invalid={error !== undefined}
                    aria-describedby={error ? 'bookmark-note-error' : undefined}
                    className="w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-xs outline-none placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50"
                />
                <InputError
                    id="bookmark-note-error"
                    role="alert"
                    message={error}
                />
            </div>
            <DialogFooter className="gap-2 sm:justify-between">
                <Button
                    type="button"
                    variant="ghost"
                    className="text-destructive"
                    onClick={remove}
                    disabled={busy}
                >
                    <Trash2 />
                    {t('quran.bookmark_remove')}
                </Button>
                <div className="flex gap-2">
                    <Button
                        type="button"
                        variant="outline"
                        onClick={onClose}
                        disabled={busy}
                    >
                        {t('quran.cancel')}
                    </Button>
                    <Button type="submit" disabled={busy}>
                        {t('quran.save')}
                    </Button>
                </div>
            </DialogFooter>
        </form>
    );
}
