import { Check, Copy, ExternalLink, Tv } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { useClipboard } from '@/hooks/use-clipboard';
import { useT } from '@/lib/i18n';
import { Section } from './controls';

const TIPS = [
    'tip_browser',
    'tip_kiosk',
    'tip_chromecast',
    'tip_firetv',
    'tip_tablet',
    'tip_power',
] as const;

/** The screen's address to open on the TV, and how to set one up. */
export function ScreenLink({ url }: { url: string }) {
    const t = useT();
    const [copied, copy] = useClipboard();

    return (
        <Section
            id="screen"
            title={t('display.section_screen')}
            description={t('display.section_screen_hint')}
            icon={Tv}
        >
            <div className="flex gap-2">
                <Input
                    readOnly
                    value={url}
                    dir="ltr"
                    onFocus={(event) => event.target.select()}
                    aria-label={t('display.screen_url')}
                    className="font-mono text-xs"
                />
                <Button
                    type="button"
                    variant="outline"
                    size="icon"
                    onClick={() => void copy(url)}
                    aria-label={t('display.copy')}
                    title={t('display.copy')}
                >
                    {copied === url ? (
                        <Check className="size-4 text-primary" />
                    ) : (
                        <Copy className="size-4" />
                    )}
                </Button>
                <Button type="button" variant="outline" size="icon" asChild>
                    <a
                        href={url}
                        target="_blank"
                        rel="noopener"
                        aria-label={t('display.open_screen')}
                        title={t('display.open_screen')}
                    >
                        <ExternalLink className="size-4" />
                    </a>
                </Button>
            </div>
            <details className="group rounded-xl bg-muted/60 px-4 py-3 text-sm">
                <summary className="cursor-pointer font-medium marker:text-muted-foreground">
                    {t('display.tips_title')}
                </summary>
                <ol className="mt-3 list-decimal space-y-2 ps-5 text-muted-foreground">
                    {TIPS.map((tip) => (
                        <li key={tip}>{t(`display.${tip}`)}</li>
                    ))}
                </ol>
            </details>
        </Section>
    );
}
