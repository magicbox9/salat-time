import { Head } from '@inertiajs/react';
import type { SiteMeta } from './site-types';

/** Title, description and link-preview tags of a page of a mosque's site. */
export function SiteHead({ meta }: { meta: SiteMeta }) {
    return (
        <Head title={meta.title}>
            <meta
                head-key="description"
                name="description"
                content={meta.description}
            />
            <meta
                head-key="og:title"
                property="og:title"
                content={meta.title}
            />
            <meta
                head-key="og:description"
                property="og:description"
                content={meta.description}
            />
            <meta head-key="og:type" property="og:type" content={meta.type} />
            <meta head-key="og:url" property="og:url" content={meta.url} />
            <link head-key="canonical" rel="canonical" href={meta.url} />
            {meta.image && (
                <meta
                    head-key="og:image"
                    property="og:image"
                    content={meta.image}
                />
            )}
            <meta
                head-key="twitter:card"
                name="twitter:card"
                content={meta.image ? 'summary_large_image' : 'summary'}
            />
        </Head>
    );
}
