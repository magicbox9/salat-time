import { CompactSiteBand } from './site-band';
import { accentStyle } from './accent';
import { SiteNav } from './site-nav';
import type { SiteSection } from './site-nav';
import type { SiteShell } from './site-types';

type Props = {
    site: SiteShell;
    current: SiteSection;
    /** The home page draws its own, larger band (with the visitor's actions). */
    band?: React.ReactNode;
    children: React.ReactNode;
};

/** Every page of a mosque's site: its band, its menu, its colour. */
export function MosqueSiteShell({ site, current, band, children }: Props) {
    return (
        <div
            style={accentStyle(site.accent)}
            // Text and icons in the mosque's colour: darkened if pale on the light theme,
            // lightened on the night-sky background.
            className="space-y-4 [--site-accent-ink:var(--site-accent-ink-light)] sm:space-y-6 dark:[--site-accent-ink:color-mix(in_oklab,var(--site-accent)_60%,white)]"
        >
            {band ?? <CompactSiteBand site={site} />}
            <SiteNav site={site} current={current} />
            <div className="pt-2">{children}</div>
        </div>
    );
}
