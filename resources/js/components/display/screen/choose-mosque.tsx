import { Link } from '@inertiajs/react';
import { Compass, Settings2 } from 'lucide-react';
import { SiteLogoMark } from '@/components/site/site-logo';
import { useT } from '@/lib/i18n';

/** /display before a mosque is chosen: a friendly way to pick one. */
export function ChooseMosque() {
    const t = useT();

    return (
        <div
            className="flex min-h-svh flex-col items-center justify-center gap-6 px-6 py-12 text-center text-white"
            style={{
                background:
                    'radial-gradient(120% 90% at 50% 0%, #0f4a3b 0%, #08342a 45%, #04211b 100%)',
            }}
        >
            <SiteLogoMark className="size-16 rounded-2xl shadow-xl" />
            <h1 className="max-w-xl text-3xl font-semibold tracking-tight text-balance sm:text-4xl">
                {t('display.choose_title')}
            </h1>
            <p className="max-w-lg text-base leading-relaxed text-pretty text-white/75">
                {t('display.choose_body')}
            </p>
            <div className="flex flex-wrap items-center justify-center gap-3">
                <Link
                    href="/explore"
                    className="inline-flex items-center gap-2 rounded-full bg-[var(--gold)] px-6 py-3 font-semibold text-[#062a22] shadow-lg transition-transform hover:scale-[1.02] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white motion-reduce:transition-none"
                >
                    <Compass className="size-5" aria-hidden />
                    {t('display.choose_action')}
                </Link>
                <Link
                    href="/display/settings"
                    className="inline-flex items-center gap-2 rounded-full px-5 py-3 text-white/85 ring-1 ring-white/25 transition-colors hover:bg-white/10 focus-visible:outline-2 focus-visible:outline-white"
                >
                    <Settings2 className="size-5" aria-hidden />
                    {t('display.personal_settings')}
                </Link>
            </div>
        </div>
    );
}
