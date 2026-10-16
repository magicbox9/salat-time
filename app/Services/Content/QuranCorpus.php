<?php

namespace App\Services\Content;

use Illuminate\Support\Facades\Cache;
use RuntimeException;

/**
 * The KFGQPC Hafs corpus (v2.0), read from the verified, unchanged JSON in
 * resources/quran/Hafs. The file is parsed once, then every surah is cached
 * on its own so a page only ever loads the ayat it shows.
 *
 * The text is never edited: aya_text is passed through exactly as published
 * (its terminal glyph is the numbered ayah mark of the KFGQPC font).
 */
class QuranCorpus
{
    public const EDITION = 'hafs';

    public const VERSION = '2.0';

    public const DATA_PATH = 'quran/Hafs/hafsData_v2-0.json';

    /** Pinned like build.sh in the Mac app; also listed in source-manifest.json. */
    public const DATA_SHA256 = 'd2960b3217962e7e4252abdcece67bea3d6b48271e4cd3af45bbbb2dd5c872ca';

    public const SURAH_COUNT = 114;

    public const AYAH_COUNT = 6236;

    /** Recitation is Hafs-numbered verse-by-verse audio from EveryAyah.com. */
    public const RECITERS = [
        ['id' => 'Alafasy_128kbps', 'name_ar' => 'مشاري راشد العفاسي', 'name' => 'Mishary Rashid Alafasy'],
        ['id' => 'Husary_128kbps', 'name_ar' => 'محمود خليل الحصري', 'name' => 'Mahmoud Khalil Al-Husary'],
        ['id' => 'Abdul_Basit_Murattal_192kbps', 'name_ar' => 'عبد الباسط عبد الصمد (مرتّل)', 'name' => 'Abdul Basit (Murattal)'],
        ['id' => 'Minshawy_Murattal_128kbps', 'name_ar' => 'محمد صديق المنشاوي (مرتّل)', 'name' => 'Mohamed Siddiq Al-Minshawi (Murattal)'],
    ];

    /** Bumped whenever the cached shape changes, so old entries are never served. */
    private const CACHE_VERSION = 1;

    /** @var array{index: list<array{number: int, name_ar: string, name_en: string, ayah_count: int, juz: int, page: int, end_page: int}>, surahs: array<int, list<array{ayah: int, text: string, juz: int, page: int}>>}|null */
    private ?array $parsed = null;

    /** @var list<array{number: int, name_ar: string, name_en: string, ayah_count: int, juz: int, page: int, end_page: int}>|null */
    private ?array $index = null;

    /**
     * The 114 surahs: number, Arabic and transliterated names, ayah count,
     * and where each starts (juz, page) and ends (page).
     *
     * @return list<array{number: int, name_ar: string, name_en: string, ayah_count: int, juz: int, page: int, end_page: int}>
     */
    public function surahs(): array
    {
        // Kept on the instance: a page listing many bookmarks asks for
        // surah names repeatedly and must not hit the cache store each time.
        return $this->index ??= Cache::rememberForever($this->key('index'), fn () => $this->parse()['index']);
    }

    /** @return array{number: int, name_ar: string, name_en: string, ayah_count: int, juz: int, page: int, end_page: int}|null */
    public function surah(int $number): ?array
    {
        return $this->exists($number) ? $this->surahs()[$number - 1] : null;
    }

    public function exists(int $number): bool
    {
        return $number >= 1 && $number <= self::SURAH_COUNT;
    }

    public function ayahCount(int $surah): int
    {
        return $this->surah($surah)['ayah_count'] ?? 0;
    }

    /**
     * One surah's ayat, exactly as published.
     *
     * @return list<array{ayah: int, text: string, juz: int, page: int}>
     */
    public function ayat(int $surah): array
    {
        if (! $this->exists($surah)) {
            return [];
        }

        return Cache::rememberForever($this->key("surah:$surah"), fn () => $this->parse()['surahs'][$surah]);
    }

    /**
     * The basmala heading shown above every surah except Al-Fātiḥah (where it
     * is ayah 1) and At-Tawbah. It is the publisher's own 1:1 string with only
     * the terminal ayah mark removed, the one rendering derivative allowed.
     */
    public function basmala(): string
    {
        return self::stripAyahMark($this->ayat(1)[0]['text'] ?? '');
    }

    public static function stripAyahMark(string $text): string
    {
        // Unicode-aware (trim() works on bytes and could split a letter).
        $text = (string) preg_replace('/[\x{FC00}-\x{FDFF}]/u', '', $text);

        return (string) preg_replace('/^[\s\x{00A0}]+|[\s\x{00A0}]+$/u', '', $text);
    }

    public static function dataPath(): string
    {
        return resource_path(self::DATA_PATH);
    }

    private function key(string $suffix): string
    {
        return 'quran:v'.self::CACHE_VERSION.':'.self::EDITION.':'.substr(self::DATA_SHA256, 0, 12).':'.$suffix;
    }

    /**
     * Parses the corpus once and caches every surah, so later requests read
     * one small cache entry instead of the 3.6 MB file.
     *
     * @return array{index: list<array{number: int, name_ar: string, name_en: string, ayah_count: int, juz: int, page: int, end_page: int}>, surahs: array<int, list<array{ayah: int, text: string, juz: int, page: int}>>}
     */
    private function parse(): array
    {
        if ($this->parsed !== null) {
            return $this->parsed;
        }

        $rows = json_decode((string) @file_get_contents(self::dataPath()), true);
        if (! is_array($rows) || count($rows) !== self::AYAH_COUNT) {
            throw new RuntimeException('The Hafs corpus is missing or incomplete.');
        }

        $surahs = [];
        $index = [];
        foreach ($rows as $row) {
            $number = (int) $row['sura_no'];
            $surahs[$number][] = [
                'ayah' => (int) $row['aya_no'],
                'text' => (string) $row['aya_text'],
                'juz' => (int) $row['jozz'],
                'page' => (int) $row['page'],
            ];
            $index[$number] ??= [
                'number' => $number,
                'name_ar' => (string) $row['sura_name_ar'],
                'name_en' => (string) $row['sura_name_en'],
                'ayah_count' => 0,
                'juz' => (int) $row['jozz'],
                'page' => (int) $row['page'],
                'end_page' => (int) $row['page'],
            ];
            $index[$number]['ayah_count']++;
            $index[$number]['end_page'] = (int) $row['page'];
        }
        ksort($index);

        if (count($index) !== self::SURAH_COUNT) {
            throw new RuntimeException('The Hafs corpus does not contain 114 surahs.');
        }

        $this->parsed = ['index' => array_values($index), 'surahs' => $surahs];

        $entries = [$this->key('index') => $this->parsed['index']];
        foreach ($surahs as $number => $ayat) {
            $entries[$this->key("surah:$number")] = $ayat;
        }
        Cache::putMany($entries, null);

        return $this->parsed;
    }
}
