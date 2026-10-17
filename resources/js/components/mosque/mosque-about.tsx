import { Link } from '@inertiajs/react';
import { ArrowRight } from 'lucide-react';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { LinkedText } from './linked-text';
import type { SiteMosqueDetails } from './site-types';

const PREVIEW = 420;

type Props = {
    mosque: SiteMosqueDetails;
    aboutPage: { title: string; slug: string } | null;
};

/** About the mosque: the start of its description, and its "About us" page. */
export function MosqueAbout({ mosque, aboutPage }: Props) {
    const t = useT();
    const [expanded, setExpanded] = useState(false);
    const text = mosque.description ?? '';
    const long = Array.from(text).length > PREVIEW;
    const shown =
        long && !expanded
            ? `${Array.from(text).slice(0, PREVIEW).join('').trimEnd()}…`
            : text;

    return (
        <section
            aria-labelledby="about-mosque"
            className="rounded-2xl border bg-card p-5 shadow-xs"
        >
            <h2 id="about-mosque" className="font-semibold">
                {t('mosque.about')}
            </h2>
            {text ? (
                <LinkedText
                    text={shown}
                    className="mt-2 text-sm leading-relaxed text-muted-foreground"
                />
            ) : (
                <p className="mt-2 text-sm text-muted-foreground">
                    {t('mosque.no_description')}
                </p>
            )}
            <div className="mt-3 flex flex-wrap items-center gap-2">
                {long && (
                    <Button
                        variant="link"
                        size="sm"
                        className="h-auto px-0"
                        onClick={() => setExpanded(!expanded)}
                    >
                        {expanded
                            ? t('mosque.show_less')
                            : t('mosque.read_more')}
                    </Button>
                )}
                {aboutPage && (
                    <Button
                        asChild
                        size="sm"
                        variant="outline"
                        className="ms-auto"
                    >
                        <Link
                            href={`/mosques/${mosque.slug}/pages/${aboutPage.slug}`}
                        >
                            {aboutPage.title}
                            <ArrowRight
                                className="size-4 rtl:-scale-x-100"
                                aria-hidden
                            />
                        </Link>
                    </Button>
                )}
            </div>
        </section>
    );
}
