import { Link } from '@inertiajs/react';
import { ArrowRight, Megaphone } from 'lucide-react';
import { useT } from '@/lib/i18n';
import type { PostCardData } from './site-types';

/** The mosque's pinned announcements, quietly above everything else. */
export function PinnedBanner({ posts }: { posts: PostCardData[] }) {
    const t = useT();

    if (posts.length === 0) {
        return null;
    }

    return (
        <section
            aria-label={t('mosquesite.pinned_label')}
            className="space-y-2"
        >
            {posts.map((post) => (
                <Link
                    key={post.id}
                    href={post.url}
                    className="group flex items-start gap-3 rounded-2xl border border-gold/50 bg-gradient-to-r from-gold/15 via-gold/5 to-transparent px-4 py-3 transition-colors outline-none hover:border-gold focus-visible:ring-2 focus-visible:ring-gold/60 sm:items-center sm:px-5 rtl:bg-gradient-to-l"
                >
                    <span className="mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-full bg-gold/25 sm:mt-0">
                        <Megaphone
                            className="size-4 text-foreground"
                            aria-hidden
                        />
                    </span>
                    <span className="min-w-0 flex-1">
                        <span className="block text-xs font-medium tracking-wide text-muted-foreground uppercase">
                            {post.category?.name ??
                                t('mosquesite.pinned_label')}
                        </span>
                        <span
                            dir="auto"
                            className="block font-semibold break-words"
                        >
                            {post.title}
                        </span>
                        {post.excerpt && (
                            <span
                                dir="auto"
                                className="mt-0.5 line-clamp-2 block text-sm text-muted-foreground"
                            >
                                {post.excerpt}
                            </span>
                        )}
                    </span>
                    <ArrowRight
                        className="mt-1 size-4 shrink-0 text-muted-foreground transition-transform motion-safe:group-hover:translate-x-0.5 sm:mt-0 rtl:-scale-x-100 rtl:motion-safe:group-hover:-translate-x-0.5"
                        aria-hidden
                    />
                </Link>
            ))}
        </section>
    );
}
