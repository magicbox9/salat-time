import { Head, usePage } from '@inertiajs/react';
import { CategoryCard } from '@/components/adhkar/category-card';
import { suggestedCategories } from '@/components/adhkar/types';
import type { AdhkarCategory } from '@/components/adhkar/types';
import { useAdhkarDoneToday } from '@/components/adhkar/use-adhkar-progress';
import { QuranFonts } from '@/components/quran/quran-fonts';
import { useNow } from '@/hooks/use-now';
import { useT } from '@/lib/i18n';

type Props = {
    categories: AdhkarCategory[];
};

const FEATURED = ['morning', 'evening'];

export default function AdhkarIndex({ categories }: Props) {
    const t = useT();
    const { locale } = usePage().props;
    const now = useNow(60_000);
    const done = useAdhkarDoneToday();
    const { primary, night } = suggestedCategories(now);
    const featured = FEATURED.map((key) =>
        categories.find((c) => c.key === key),
    ).filter((c): c is AdhkarCategory => c !== undefined);
    const others = categories.filter((c) => !FEATURED.includes(c.key));

    return (
        <>
            <Head title={t('adhkar.title')} />
            <QuranFonts />

            <header className="max-w-2xl">
                {locale !== 'ar' && (
                    <p
                        dir="rtl"
                        lang="ar"
                        aria-hidden
                        className="font-adhkar mb-1 text-start text-4xl text-gold sm:text-5xl"
                    >
                        الأذكار
                    </p>
                )}
                <h1 className="text-2xl font-semibold sm:text-3xl">
                    {t('adhkar.title')}
                </h1>
                <p className="mt-2 text-muted-foreground">
                    {t('adhkar.intro')}
                </p>
            </header>

            <section className="mt-8 grid gap-4 md:grid-cols-2">
                {featured.map((category) => (
                    <CategoryCard
                        key={category.key}
                        category={category}
                        done={done[category.key] ?? 0}
                        featured
                        badge={
                            category.key === primary
                                ? t('adhkar.suggested')
                                : null
                        }
                        subtitle={t(`adhkar.when_${category.key}`)}
                    />
                ))}
            </section>

            <section className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
                {others.map((category) => (
                    <CategoryCard
                        key={category.key}
                        category={category}
                        done={done[category.key] ?? 0}
                        badge={
                            category.key === 'sleep' && night
                                ? t('adhkar.tonight')
                                : null
                        }
                        subtitle={
                            category.key === 'sleep'
                                ? t('adhkar.when_sleep')
                                : null
                        }
                    />
                ))}
            </section>

            <footer className="mt-10 space-y-1 text-center text-xs text-muted-foreground">
                <p>{t('adhkar.progress_note')}</p>
                <p>{t('adhkar.data_credit')}</p>
            </footer>
        </>
    );
}
