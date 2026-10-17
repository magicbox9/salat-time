import { ExternalLink, Play } from 'lucide-react';
import { useState } from 'react';
import { useT } from '@/lib/i18n';
import type { VideoEmbedData } from './site-types';

/**
 * The khutbah recording. Nothing is loaded from YouTube or Vimeo until the
 * visitor presses play; then their privacy-enhanced player opens in a
 * sandboxed frame (the server only ever sends youtube-nocookie.com or
 * player.vimeo.com addresses).
 */
export function ArticleVideo({
    video,
    title,
    poster,
}: {
    video: VideoEmbedData;
    title: string;
    poster: string | null;
}) {
    const t = useT();
    const [playing, setPlaying] = useState(false);
    const provider = video.provider === 'youtube' ? 'YouTube' : 'Vimeo';
    const src = `${video.embed_url}${video.embed_url.includes('?') ? '&' : '?'}autoplay=1`;

    return (
        <figure className="space-y-2">
            <div className="relative aspect-video overflow-hidden rounded-2xl bg-black shadow-sm">
                {playing ? (
                    <iframe
                        src={src}
                        title={t('mosquesite.video_of', { title })}
                        className="absolute inset-0 size-full"
                        sandbox="allow-scripts allow-same-origin allow-presentation allow-popups"
                        allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
                        allowFullScreen
                        referrerPolicy="strict-origin-when-cross-origin"
                        loading="lazy"
                    />
                ) : (
                    <button
                        type="button"
                        onClick={() => setPlaying(true)}
                        className="group absolute inset-0 flex size-full items-center justify-center outline-none focus-visible:ring-4 focus-visible:ring-[var(--site-accent)]/60"
                        aria-label={t('mosquesite.play_video', { provider })}
                    >
                        {poster ? (
                            <img
                                src={poster}
                                alt=""
                                className="absolute inset-0 size-full object-cover opacity-60"
                            />
                        ) : (
                            <span className="absolute inset-0 bg-gradient-to-br from-[var(--site-accent)] to-black" />
                        )}
                        <span className="relative flex size-16 items-center justify-center rounded-full bg-white/95 text-black shadow-xl transition-transform motion-safe:group-hover:scale-105">
                            {/* The triangle always points right: a physical nudge centres it, in RTL too. */}
                            <Play
                                className="ml-1 size-7 fill-current"
                                aria-hidden
                            />
                        </span>
                    </button>
                )}
            </div>
            <figcaption className="flex flex-wrap items-center justify-between gap-2 text-xs text-muted-foreground">
                <span>
                    {playing
                        ? t('mosquesite.video_playing', { provider })
                        : t('mosquesite.video_privacy', { provider })}
                </span>
                <a
                    href={video.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-1 hover:text-foreground hover:underline"
                >
                    {t('mosquesite.watch_on', { provider })}
                    <ExternalLink className="size-3" aria-hidden />
                </a>
            </figcaption>
        </figure>
    );
}
