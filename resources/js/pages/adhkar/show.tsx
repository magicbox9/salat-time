import { Head, Link, usePage } from '@inertiajs/react';
import { ArrowLeft, ArrowRight, CheckCircle2, RotateCcw } from 'lucide-react';
import { useEffect, useRef } from 'react';
import { DhikrCard } from '@/components/adhkar/dhikr-card';
import { categoryIcon } from '@/components/adhkar/types';
import type { AdhkarCategory, Dhikr } from '@/components/adhkar/types';
import { useAdhkarAudio } from '@/components/adhkar/use-adhkar-audio';
import { useCategoryProgress } from '@/components/adhkar/use-adhkar-progress';
import { QuranFonts } from '@/components/quran/quran-fonts';
import { countLabel } from '@/components/quran/types';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';

type Props = {
    category: AdhkarCategory;
    items: Dhikr[];
    related: AdhkarCategory[];
};

export default function AdhkarShow(props: Props) {
    const t = useT();

    return (
        <>
            <Head title={t(`adhkar.cat_${props.category.key}`)} />
            <QuranFonts preloadFace="amiri" />
            {/* A fresh reader (counts, audio) for each category. */}
            <CategoryReader key={props.category.key} {...props} />
        </>
    );
}

/** Controls (native or ARIA widgets such as menus) keep the Space key. */
const CONTROLS =
    'input, textarea, select, button, a, [contenteditable], [role="button"], [role="link"], [role="menuitem"], [role="option"], [role="checkbox"], [role="switch"], [role="tab"], [role="slider"], [role="dialog"], [role="menu"], [role="listbox"]';

function isOnControl(event: KeyboardEvent): boolean {
    return (
        event.defaultPrevented ||
        (event.target instanceof Element &&
            event.target.closest(CONTROLS) !== null)
    );
}

function CategoryReader({ category, items, related }: Props) {
    const t = useT();
    const { dir } = usePage().props;
    const totals = Object.fromEntries(
        items.map((item) => [item.id, item.count]),
    );
    const progress = useCategoryProgress(category.key, totals);
    const audio = useAdhkarAudio();
    const completed = items.filter(
        (item) => (progress.counts[item.id] ?? 0) >= item.count,
    ).length;
    const activeIndex = items.findIndex(
        (item) => (progress.counts[item.id] ?? 0) < item.count,
    );
    const allDone = activeIndex === -1;
    const Icon = categoryIcon(category.key);
    const Back = dir === 'rtl' ? ArrowRight : ArrowLeft;
    const tapRef = useRef<() => void>(() => {});

    const tap = (index: number) => {
        const item = items[index];
        if (!progress.increment(item.id)) {
            return;
        }
        // The dhikr is complete: bring the next unfinished one into view.
        const nextIndex = items.findIndex(
            (other, i) =>
                i > index && (progress.counts[other.id] ?? 0) < other.count,
        );
        window.setTimeout(() => {
            const target =
                nextIndex === -1 ? 'adhkar-complete' : `dhikr-${nextIndex + 1}`;
            document
                .getElementById(target)
                ?.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }, 350);
    };

    useEffect(() => {
        tapRef.current = () => activeIndex !== -1 && tap(activeIndex);
    });

    // Space counts the current dhikr when focus is not on a control.
    useEffect(() => {
        const onKey = (event: KeyboardEvent) => {
            if (
                event.code === 'Space' &&
                !event.repeat &&
                !event.altKey &&
                !event.ctrlKey &&
                !event.metaKey &&
                !isOnControl(event)
            ) {
                event.preventDefault();
                tapRef.current();
            }
        };
        window.addEventListener('keydown', onKey);

        return () => window.removeEventListener('keydown', onKey);
    }, []);

    return (
        <div className="mx-auto max-w-3xl">
            <Link
                href="/adhkar"
                className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-primary"
            >
                <Back className="size-4" />
                {t('adhkar.all')}
            </Link>

            <header className="mt-4 flex flex-col gap-4 sm:flex-row sm:items-center">
                <span className="grid size-14 shrink-0 place-items-center rounded-2xl bg-primary/10 text-primary">
                    <Icon className="size-7" />
                </span>
                <div className="min-w-0 flex-1">
                    <h1 className="text-2xl font-semibold sm:text-3xl">
                        {t(`adhkar.cat_${category.key}`)}
                    </h1>
                    <p className="mt-1 text-sm text-muted-foreground">
                        <span
                            dir="rtl"
                            lang="ar"
                            className="font-adhkar text-base"
                        >
                            {category.name_ar}
                        </span>
                        <span aria-hidden> · </span>
                        {countLabel(t, 'adhkar.items', category.count)}
                    </p>
                </div>
            </header>

            <div className="sticky top-16 z-20 -mx-1 mt-6 rounded-xl border bg-background/90 p-3 shadow-sm backdrop-blur">
                <div className="flex items-center justify-between gap-3 text-sm">
                    <span className="font-medium">
                        {t('adhkar.progress', {
                            done: completed,
                            total: items.length,
                        })}
                    </span>
                    {Object.keys(progress.counts).length > 0 && (
                        <Button
                            variant="ghost"
                            size="sm"
                            onClick={progress.resetAll}
                        >
                            <RotateCcw />
                            {t('adhkar.start_again')}
                        </Button>
                    )}
                </div>
                <div
                    className="mt-2 h-1.5 overflow-hidden rounded-full bg-muted"
                    aria-hidden
                >
                    <div
                        className={
                            allDone
                                ? 'h-full rounded-full bg-gold transition-all'
                                : 'h-full rounded-full bg-primary transition-all'
                        }
                        style={{
                            width: `${(completed / Math.max(1, items.length)) * 100}%`,
                        }}
                    />
                </div>
            </div>

            <p className="mt-4 text-center text-xs text-muted-foreground">
                {t('adhkar.count_hint')}
            </p>

            <div className="mt-4 space-y-5">
                {items.map((item, index) => (
                    <DhikrCard
                        key={item.id}
                        dhikr={item}
                        position={index + 1}
                        total={items.length}
                        count={progress.counts[item.id] ?? 0}
                        active={index === activeIndex}
                        audio={audio.state}
                        onTap={() => tap(index)}
                        onReset={() => progress.reset(item.id)}
                        onListen={() =>
                            item.audio && audio.toggle(item.id, item.audio.url)
                        }
                    />
                ))}
            </div>

            {allDone && (
                <section
                    id="adhkar-complete"
                    className="mt-6 scroll-mt-40 rounded-2xl border border-gold/50 bg-gold/10 p-6 text-center"
                >
                    <CheckCircle2 className="mx-auto size-10 text-gold" />
                    <h2 className="mt-3 text-xl font-semibold">
                        {t('adhkar.completed_title')}
                    </h2>
                    <p className="mt-1 text-muted-foreground">
                        {t('adhkar.completed_body')}
                    </p>
                    <Button
                        variant="outline"
                        className="mt-4"
                        onClick={progress.resetAll}
                    >
                        <RotateCcw />
                        {t('adhkar.start_again')}
                    </Button>
                </section>
            )}

            <section className="mt-10">
                <h2 className="text-sm font-semibold tracking-wide text-muted-foreground uppercase">
                    {t('adhkar.more')}
                </h2>
                <div className="mt-3 flex flex-wrap gap-2">
                    {related.map((other) => {
                        const OtherIcon = categoryIcon(other.key);

                        return (
                            <Link
                                key={other.key}
                                href={`/adhkar/${other.key}`}
                                className="inline-flex items-center gap-2 rounded-full border bg-card px-3 py-1.5 text-sm transition-colors hover:border-primary/40 hover:text-primary"
                            >
                                <OtherIcon className="size-4 text-primary" />
                                {t(`adhkar.cat_${other.key}`)}
                            </Link>
                        );
                    })}
                </div>
            </section>

            <footer className="mt-10 space-y-1 text-center text-xs text-muted-foreground">
                <p>{t('adhkar.audio_note')}</p>
                <p>{t('adhkar.progress_note')}</p>
                <p>{t('adhkar.data_credit')}</p>
            </footer>
        </div>
    );
}
