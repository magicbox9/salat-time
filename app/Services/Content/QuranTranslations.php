<?php

namespace App\Services\Content;

use Illuminate\Support\Facades\Cache;
use PDO;

/**
 * Translations of the meanings from QuranEnc.com: verbatim, versioned SQLite
 * snapshots copied unchanged from the Mac app. They use the Hafs verse keys
 * only and are never attached to another riwayah.
 *
 * QuranEnc's terms ask for: no modification, the publisher and source named,
 * and the version shown. The reader shows `title`, `version` and the source.
 */
class QuranTranslations
{
    public const DIR = 'quran/Translations/QuranEnc';

    /** @var array<string, array{key: string, file: string, title: string, translator: string, version: string, language: string, direction: string, sha256: string}> */
    public const AVAILABLE = [
        'en' => [
            'key' => 'english_rwwad',
            'file' => 'english_rwwad_v1.0.19.sqlite',
            'title' => 'English Translation - Rowwad Translation Center',
            'translator' => 'Rowwad Translation Center',
            'version' => '1.0.19',
            'language' => 'en',
            'direction' => 'ltr',
            'sha256' => '77e2ede3d8e6d6b5c6e16ff78eda2d2b6cc0a6b7489c94a5dde4f7481f5fdee8',
        ],
        'fr' => [
            'key' => 'french_rashid',
            'file' => 'french_rashid_v1.0.3.sqlite',
            'title' => 'French Translation - Rachid Maach',
            'translator' => 'Rachid Maach',
            'version' => '1.0.3',
            'language' => 'fr',
            'direction' => 'ltr',
            'sha256' => '1c8d1f66f3ab8d708ba84db79b8c069dede23a3e40fff253d3ca14deafba87bf',
        ],
    ];

    public const SOURCE_URL = 'https://quranenc.com/en/browse/';

    /** Bumped whenever the cached shape changes, so old entries are never served. */
    private const CACHE_VERSION = 1;

    /**
     * What the reader can offer, without the rows.
     *
     * @return list<array{code: string, title: string, translator: string, version: string, language: string, source_url: string}>
     */
    public function options(): array
    {
        return array_map(fn (array $t, string $code) => [
            'code' => $code,
            'title' => $t['title'],
            'translator' => $t['translator'],
            'version' => $t['version'],
            'language' => $t['language'],
            'source_url' => self::SOURCE_URL.$t['key'],
        ], self::AVAILABLE, array_keys(self::AVAILABLE));
    }

    public function has(string $code): bool
    {
        return isset(self::AVAILABLE[$code]);
    }

    /**
     * One surah of a translation, keyed by ayah number.
     *
     * @return array{code: string, title: string, translator: string, version: string, language: string, direction: string, source_url: string, ayat: array<int, array{text: string, notes: string|null}>}|null
     */
    public function forSurah(string $code, int $surah): ?array
    {
        $meta = self::AVAILABLE[$code] ?? null;
        if ($meta === null || $surah < 1 || $surah > QuranCorpus::SURAH_COUNT) {
            return null;
        }

        $ayat = Cache::rememberForever(
            'quran:tr:v'.self::CACHE_VERSION.':'.$meta['key'].':'.substr($meta['sha256'], 0, 12).':'.$surah,
            fn () => $this->read($meta['file'], $surah),
        );

        return [
            'code' => $code,
            'title' => $meta['title'],
            'translator' => $meta['translator'],
            'version' => $meta['version'],
            'language' => $meta['language'],
            'direction' => $meta['direction'],
            'source_url' => self::SOURCE_URL.$meta['key'],
            'ayat' => $ayat,
        ];
    }

    public static function path(string $file): string
    {
        return resource_path(self::DIR.'/'.$file);
    }

    /** @return array<int, array{text: string, notes: string|null}> */
    private function read(string $file, int $surah): array
    {
        $pdo = new PDO('sqlite:'.self::path($file), null, null, [
            PDO::SQLITE_ATTR_OPEN_FLAGS => PDO::SQLITE_OPEN_READONLY,
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        ]);
        $statement = $pdo->prepare('SELECT aya, translation, footnotes FROM translations WHERE sura = ? ORDER BY aya');
        $statement->execute([$surah]);

        $ayat = [];
        foreach ($statement->fetchAll(PDO::FETCH_ASSOC) as $row) {
            $notes = trim((string) $row['footnotes']);
            $ayat[(int) $row['aya']] = [
                'text' => (string) $row['translation'],
                'notes' => $notes === '' ? null : (string) $row['footnotes'],
            ];
        }

        return $ayat;
    }
}
