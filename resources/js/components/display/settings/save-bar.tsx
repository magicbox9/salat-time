import { CheckCircle2, RotateCcw, TriangleAlert } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Spinner } from '@/components/ui/spinner';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';

/** Stays at the bottom of the window: unsaved changes, errors, save. */
export function SaveBar({
    dirty,
    processing,
    hasErrors,
    onSave,
    onReset,
    savedLabel,
}: {
    dirty: boolean;
    processing: boolean;
    hasErrors: boolean;
    onSave: () => void;
    onReset: () => void;
    savedLabel?: string;
}) {
    const t = useT();

    return (
        <div className="sticky bottom-4 z-20">
            <div
                className={cn(
                    'mx-auto flex max-w-3xl flex-wrap items-center gap-3 rounded-2xl border bg-background/90 px-4 py-3 shadow-lg backdrop-blur transition-colors',
                    dirty && 'border-primary/40',
                    hasErrors && 'border-destructive/50',
                )}
                role="status"
                aria-live="polite"
            >
                <span className="flex min-w-0 flex-1 items-center gap-2 text-sm">
                    {hasErrors ? (
                        <>
                            <TriangleAlert
                                className="size-4 shrink-0 text-destructive"
                                aria-hidden
                            />
                            {t('display.has_errors')}
                        </>
                    ) : dirty ? (
                        <>
                            <span
                                className="size-2 shrink-0 rounded-full bg-gold"
                                aria-hidden
                            />
                            {t('display.unsaved')}
                        </>
                    ) : (
                        <>
                            <CheckCircle2
                                className="size-4 shrink-0 text-primary"
                                aria-hidden
                            />
                            <span className="text-muted-foreground">
                                {savedLabel ?? t('display.all_saved')}
                            </span>
                        </>
                    )}
                </span>
                <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={onReset}
                    disabled={!dirty || processing}
                    aria-label={t('display.discard')}
                    title={t('display.discard')}
                >
                    <RotateCcw className="size-4" />
                    <span className="hidden sm:inline">
                        {t('display.discard')}
                    </span>
                </Button>
                <Button
                    type="button"
                    size="sm"
                    onClick={onSave}
                    disabled={!dirty || processing}
                >
                    {processing && <Spinner />}
                    {t('display.save')}
                </Button>
            </div>
        </div>
    );
}
