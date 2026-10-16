import { preload } from 'react-dom';

/** KFGQPC Hafs v2.0: the publisher font matching the corpus (ayah marks included). */
export const HAFS_FONT_URL = '/fonts/quran/UthmanicHafs_V20.ttf';
/** Amiri Quran (SIL OFL 1.1, see /fonts/quran/AmiriQuran-OFL.txt) for adhkar. */
export const AMIRI_FONT_URL = '/fonts/quran/AmiriQuran.ttf';

const CSS = `
@font-face {
    font-family: 'KFGQPC Hafs';
    src: url('${HAFS_FONT_URL}') format('truetype');
    font-display: block;
}
@font-face {
    font-family: 'Amiri Quran';
    src: url('${AMIRI_FONT_URL}') format('truetype');
    font-display: swap;
}
.font-quran {
    font-family: 'KFGQPC Hafs', 'Amiri Quran', serif;
    font-feature-settings: normal;
    word-spacing: 0.04em;
}
.font-adhkar {
    font-family: 'Amiri Quran', 'Cairo', serif;
}
`;

type Props = {
    /** Which face the page needs right away. */
    preloadFace?: 'hafs' | 'amiri';
};

/**
 * Declares the Qur'an faces once (React hoists and dedupes the style by its
 * href), so only the pages that use them download the font files.
 */
export function QuranFonts({ preloadFace }: Props) {
    if (preloadFace) {
        preload(preloadFace === 'hafs' ? HAFS_FONT_URL : AMIRI_FONT_URL, {
            as: 'font',
            type: 'font/ttf',
            crossOrigin: 'anonymous',
        });
    }

    return (
        <style href="salat-quran-fonts" precedence="default">
            {CSS}
        </style>
    );
}
