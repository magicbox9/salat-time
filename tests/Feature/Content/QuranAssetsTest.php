<?php

namespace Tests\Feature\Content;

use App\Services\Content\QuranCorpus;
use App\Services\Content\QuranTranslations;
use PDO;
use Tests\TestCase;

/**
 * The Qur'an assets are copied unchanged from the Mac app's QuranAssets:
 * every file must still match the SHA-256 recorded in source-manifest.json
 * (and the value pinned in code), exactly like the Mac build fails closed.
 */
class QuranAssetsTest extends TestCase
{
    /** Copied file => its path in the Mac app's source-manifest.json. */
    private const ASSETS = [
        'resources/quran/Hafs/hafsData_v2-0.json' => 'Hafs/hafsData_v2-0.json',
        'resources/quran/Hafs/read.me' => 'Hafs/read.me',
        'resources/quran/Translations/QuranEnc/english_rwwad_v1.0.19.sqlite' => 'Translations/QuranEnc/english_rwwad_v1.0.19.sqlite',
        'resources/quran/Translations/QuranEnc/french_rashid_v1.0.3.sqlite' => 'Translations/QuranEnc/french_rashid_v1.0.3.sqlite',
        'resources/quran/Translations/QuranEnc/metadata-snapshot.json' => 'Translations/QuranEnc/metadata-snapshot.json',
        'public/fonts/quran/UthmanicHafs_V20.ttf' => 'Fonts/KFGQPC-Hafs/UthmanicHafs_V20.ttf',
        'public/fonts/quran/AmiriQuran.ttf' => 'Fonts/AmiriQuran/AmiriQuran.ttf',
    ];

    /** @return array<string, string> manifest path => sha256 */
    private function manifestHashes(): array
    {
        $manifest = json_decode((string) file_get_contents(resource_path('quran/source-manifest.json')), true);
        $hashes = [];
        foreach ($manifest['assets'] as $asset) {
            $hashes[$asset['path']] = $asset['sha256'];
        }
        foreach ($manifest['fontsProvenance']['entries'] as $font) {
            $hashes[$font['path']] = $font['sha256'];
        }

        return $hashes;
    }

    public function test_every_copied_asset_matches_the_manifest_hash(): void
    {
        $hashes = $this->manifestHashes();

        foreach (self::ASSETS as $local => $manifestPath) {
            $this->assertFileExists(base_path($local));
            $this->assertArrayHasKey($manifestPath, $hashes, "$manifestPath is not in the manifest");
            $this->assertSame($hashes[$manifestPath], hash_file('sha256', base_path($local)), "$local was modified");
        }
    }

    public function test_the_hashes_pinned_in_code_match_the_manifest(): void
    {
        $hashes = $this->manifestHashes();

        $this->assertSame($hashes['Hafs/hafsData_v2-0.json'], QuranCorpus::DATA_SHA256);
        $this->assertSame(QuranCorpus::DATA_SHA256, hash_file('sha256', QuranCorpus::dataPath()));
        $this->assertSame(
            '27a0727ef2f644da13b5b254befb85a7f3539d095a94caaceea2079cf5d7be5a',
            hash_file('sha256', public_path('fonts/quran/UthmanicHafs_V20.ttf')),
        );

        foreach (QuranTranslations::AVAILABLE as $translation) {
            $this->assertSame($hashes['Translations/QuranEnc/'.$translation['file']], $translation['sha256']);
            $this->assertSame($translation['sha256'], hash_file('sha256', QuranTranslations::path($translation['file'])));
        }
    }

    public function test_the_amiri_font_ships_with_its_license(): void
    {
        $this->assertStringContainsString('SIL OPEN FONT LICENSE', strtoupper((string) file_get_contents(public_path('fonts/quran/AmiriQuran-OFL.txt'))));
    }

    public function test_the_corpus_is_complete(): void
    {
        $rows = json_decode((string) file_get_contents(QuranCorpus::dataPath()), true);

        $this->assertCount(6236, $rows);
        $this->assertCount(114, array_unique(array_column($rows, 'sura_no')));
        foreach ($rows as $row) {
            $this->assertNotSame('', trim($row['aya_text']));
        }
    }

    public function test_each_translation_covers_every_hafs_ayah(): void
    {
        foreach (QuranTranslations::AVAILABLE as $translation) {
            $pdo = new PDO('sqlite:'.QuranTranslations::path($translation['file']), null, null, [
                PDO::SQLITE_ATTR_OPEN_FLAGS => PDO::SQLITE_OPEN_READONLY,
            ]);
            $stats = $pdo->query(
                "SELECT COUNT(*) AS n, COUNT(DISTINCT sura || ':' || aya) AS keys, COUNT(DISTINCT sura) AS surahs,
                        SUM(CASE WHEN TRIM(COALESCE(translation, '')) = '' THEN 1 ELSE 0 END) AS empty
                 FROM translations"
            )->fetch(PDO::FETCH_ASSOC);

            $this->assertSame(6236, (int) $stats['n'], $translation['key']);
            $this->assertSame(6236, (int) $stats['keys'], $translation['key']);
            $this->assertSame(114, (int) $stats['surahs'], $translation['key']);
            $this->assertSame(0, (int) $stats['empty'], $translation['key']);
        }
    }

    public function test_the_basmala_is_the_publisher_string_without_its_ayah_mark(): void
    {
        $corpus = app(QuranCorpus::class);
        $first = $corpus->ayat(1)[0]['text'];

        // Exactly the publisher's 1:1 minus its last two code points: the
        // no-break space and the ayah-mark glyph.
        $this->assertSame(mb_substr($first, 0, -2), $corpus->basmala());
        $this->assertSame("\u{00A0}", mb_substr($first, -2, 1));
        $this->assertSame('بسم الله الرحمن الرحيم', json_decode((string) file_get_contents(QuranCorpus::dataPath()), true)[0]['aya_text_emlaey']);
        $this->assertSame(1, preg_match('/[\x{FC00}-\x{FDFF}]$/u', $first), 'aya_text keeps its ayah mark');
    }
}
