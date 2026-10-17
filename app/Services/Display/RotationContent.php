<?php

namespace App\Services\Display;

use App\Models\Mosque;
use App\Models\MosquePost;
use App\Services\Content\AdhkarLibrary;
use App\Services\Content\QuranCorpus;
use App\Services\Content\QuranTranslations;
use App\Support\Markdown;
use Illuminate\Support\Facades\Cache;

/**
 * What the screen's rotation shows besides the mosque's own messages. Every
 * religious text comes from the verified files only: the KFGQPC corpus and
 * the QuranEnc snapshots for the Qur'an (passed through unchanged), Hisn
 * al-Muslim (resources/content/adhkar.json) for the adhkar.
 */
class RotationContent
{
    /** Bumped whenever the cached shape changes. */
    private const CACHE_VERSION = 1;

    public function __construct(
        private readonly QuranCorpus $corpus,
        private readonly QuranTranslations $translations,
        private readonly AdhkarLibrary $adhkar,
    ) {}

    /**
     * The curated verses (config display.verses) with their translations.
     *
     * @return list<array{key: string, surah: int, surah_name_ar: string, surah_name_en: string, ayat: list<array{ayah: int, text: string}>, translations: array<string, array{text: string, title: string, version: string, source_url: string}>}>
     */
    public function verses(): array
    {
        $keys = array_values(array_filter((array) config('display.verses'), 'is_string'));
        $cacheKey = 'display:verses:v'.self::CACHE_VERSION.':'.substr(QuranCorpus::DATA_SHA256, 0, 12).':'.md5(implode(',', $keys));

        return Cache::rememberForever($cacheKey, function () use ($keys) {
            $verses = [];
            foreach ($keys as $key) {
                if ($verse = $this->verse($key)) {
                    $verses[] = $verse;
                }
            }

            return $verses;
        });
    }

    /**
     * Morning and evening adhkar short enough for a screen, each tagged with
     * the time of day it belongs to.
     *
     * @return list<array{id: string, arabic: string, virtue: string|null, source: string|null, count: int, when: list<string>}>
     */
    public function adhkar(): array
    {
        $max = (int) config('display.adhkar_max_length', 320);
        $items = [];
        foreach (['morning', 'evening'] as $category) {
            foreach ($this->adhkar->items($category) ?? [] as $item) {
                if ($item['arabic'] === '' || mb_strlen($item['arabic']) > $max) {
                    continue;
                }
                $key = $item['arabic'];
                if (isset($items[$key])) {
                    $items[$key]['when'][] = $category;

                    continue;
                }
                $items[$key] = [
                    'id' => $item['id'],
                    'arabic' => $item['arabic'],
                    'virtue' => $item['virtue'],
                    'source' => $item['source'],
                    'count' => $item['count'],
                    'when' => [$category],
                ];
            }
        }

        return array_values($items);
    }

    /**
     * The adhkar said after the prayer (shown on the after-prayer slide).
     *
     * @return list<array{id: string, arabic: string, count: int, meaning_en: string|null}>
     */
    public function afterPrayer(): array
    {
        return array_map(fn (array $item) => [
            'id' => $item['id'],
            'arabic' => $item['arabic'],
            'count' => $item['count'],
            'meaning_en' => $item['meaning_en'],
        ], $this->adhkar->items('post_prayer') ?? []);
    }

    /**
     * The mosque's latest published posts (titles and a short plain-text excerpt).
     *
     * @return list<array{id: int, type: string, title: string, excerpt: string, published_at: string|null}>
     */
    public function posts(Mosque $mosque, int $limit = 5): array
    {
        return $mosque->posts()
            ->whereNotNull('published_at')
            ->where('published_at', '<=', now())
            ->orderByDesc('pinned')
            ->orderByDesc('published_at')
            ->orderByDesc('id')
            ->limit($limit)
            ->get(['id', 'type', 'title', 'excerpt', 'body', 'pinned', 'published_at'])
            ->map(fn (MosquePost $post) => [
                'id' => $post->id,
                'type' => (string) $post->type,
                'title' => (string) $post->title,
                'excerpt' => trim((string) $post->excerpt) !== '' ? (string) $post->excerpt : Markdown::excerpt($post->body, 180),
                'published_at' => $post->published_at?->toIso8601String(),
            ])
            ->values()
            ->all();
    }

    /** @return array{key: string, surah: int, surah_name_ar: string, surah_name_en: string, ayat: list<array{ayah: int, text: string}>, translations: array<string, array{text: string, title: string, version: string, source_url: string}>}|null */
    private function verse(string $key): ?array
    {
        if (! preg_match('/^(\d{1,3}):(\d{1,3})(?:-(\d{1,3}))?$/', $key, $m)) {
            return null;
        }
        $surah = (int) $m[1];
        $from = (int) $m[2];
        $to = isset($m[3]) ? (int) $m[3] : $from;
        $meta = $this->corpus->surah($surah);
        if ($meta === null || $from < 1 || $to < $from || $to > $meta['ayah_count'] || $to - $from > 4) {
            return null;
        }

        $ayat = [];
        foreach ($this->corpus->ayat($surah) as $ayah) {
            if ($ayah['ayah'] >= $from && $ayah['ayah'] <= $to) {
                $ayat[] = ['ayah' => $ayah['ayah'], 'text' => $ayah['text']];
            }
        }

        $translations = [];
        foreach (array_keys(QuranTranslations::AVAILABLE) as $code) {
            $set = $this->translations->forSurah($code, $surah);
            $parts = [];
            for ($n = $from; $n <= $to; $n++) {
                $parts[] = $set['ayat'][$n]['text'] ?? null;
            }
            if ($set !== null && ! in_array(null, $parts, true)) {
                $translations[$code] = [
                    'text' => implode(' ', $parts),
                    'title' => $set['title'],
                    'version' => $set['version'],
                    'source_url' => $set['source_url'],
                ];
            }
        }

        return [
            'key' => $key,
            'surah' => $surah,
            'surah_name_ar' => $meta['name_ar'],
            'surah_name_en' => $meta['name_en'],
            'ayat' => $ayat,
            'translations' => $translations,
        ];
    }
}
