import { Check, Link2, Mail, MessageCircle, Share2 } from 'lucide-react';
import { useEffect, useState, useSyncExternalStore } from 'react';
import { Button } from '@/components/ui/button';
import { useClipboard } from '@/hooks/use-clipboard';
import { useT } from '@/lib/i18n';

const noSubscription = () => () => undefined;

/** Share the campaign: the phone's share sheet when there is one, WhatsApp, Facebook, X, email, or copy the link. */
export function ShareButtons({ url, title }: { url: string; title: string }) {
    const t = useT();
    const [, copy] = useClipboard();
    const [copied, setCopied] = useState(false);
    // Known only in the browser: false while rendering on the server and
    // hydrating, so both renders match, then the browser's real answer.
    const canShare = useSyncExternalStore(
        noSubscription,
        () => typeof navigator.share === 'function',
        () => false,
    );

    useEffect(() => {
        if (!copied) {
            return;
        }

        const timer = window.setTimeout(() => setCopied(false), 2000);

        return () => window.clearTimeout(timer);
    }, [copied]);

    const text = `${title} — ${url}`;
    const links = [
        {
            key: 'whatsapp',
            label: 'WhatsApp',
            href: `https://wa.me/?text=${encodeURIComponent(text)}`,
            icon: MessageCircle,
        },
        {
            key: 'facebook',
            label: 'Facebook',
            href: `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}`,
            icon: Share2,
        },
        {
            key: 'x',
            label: 'X',
            href: `https://x.com/intent/post?text=${encodeURIComponent(title)}&url=${encodeURIComponent(url)}`,
            icon: Share2,
        },
        {
            key: 'email',
            label: t('fundraising.share_email'),
            href: `mailto:?subject=${encodeURIComponent(title)}&body=${encodeURIComponent(text)}`,
            icon: Mail,
        },
    ];

    return (
        <section
            aria-labelledby="share-title"
            className="rounded-3xl border bg-card p-5 shadow-xs"
        >
            <h2 id="share-title" className="font-semibold">
                {t('fundraising.share_title')}
            </h2>
            <p className="mt-1 text-sm text-muted-foreground">
                {t('fundraising.share_body')}
            </p>
            <div className="mt-4 flex flex-wrap gap-2">
                {canShare && (
                    <Button
                        type="button"
                        size="sm"
                        onClick={() =>
                            void navigator
                                .share({ title, url })
                                .catch(() => undefined)
                        }
                    >
                        <Share2 className="size-4" aria-hidden />
                        {t('fundraising.share')}
                    </Button>
                )}
                {links.map((link) => (
                    <Button key={link.key} asChild variant="outline" size="sm">
                        <a
                            href={link.href}
                            target="_blank"
                            rel="noopener noreferrer"
                        >
                            <link.icon className="size-4" aria-hidden />
                            {link.label}
                        </a>
                    </Button>
                ))}
                <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    onClick={() => void copy(url).then((ok) => setCopied(ok))}
                >
                    {copied ? (
                        <Check className="size-4 text-primary" aria-hidden />
                    ) : (
                        <Link2 className="size-4" aria-hidden />
                    )}
                    {copied
                        ? t('fundraising.copied')
                        : t('fundraising.copy_link')}
                </Button>
            </div>
        </section>
    );
}
