<?php

namespace App\Services\Content;

use Illuminate\Support\Facades\Cache;
use RuntimeException;

/**
 * Hisn al-Muslim adhkar, read from resources/content/adhkar.json (copied
 * unchanged from the Mac app). Audio is never downloaded by the server: the
 * page streams it from the publisher only after the visitor presses play.
 */
class AdhkarLibrary
{
    public const DATA_PATH = 'content/adhkar.json';

    /** Display order; keys match the JSON groups. */
    public const CATEGORIES = [
        'morning', 'evening', 'post_prayer', 'sleep', 'waking', 'after_ablution',
        'entering_mosque', 'leaving_mosque', 'before_eating', 'after_eating',
        'entering_home', 'leaving_home', 'distress', 'forgiveness',
    ];

    /**
     * Ayat al-Kursi aside, the Qur'anic adhkar of the morning and evening
     * (Al-Ikhlas, Al-Falaq, An-Nas) use Mishary Alafasy's recitation on
     * mp3quran.net, as the Mac app does. Elsewhere these numbers are
     * hisnmuslim.com recordings of other adhkar.
     */
    private const QURAN_AUDIO = ['112.mp3', '113.mp3', '114.mp3'];

    private const QURAN_AUDIO_CATEGORIES = ['morning', 'evening'];

    /** Bumped whenever the cached shape changes, so old entries are never served. */
    private const CACHE_VERSION = 1;

    /** @var array<string, mixed>|null */
    private ?array $data = null;

    /**
     * Every category with its item count and Arabic title.
     *
     * @return list<array{key: string, count: int, name_ar: string}>
     */
    public function categories(): array
    {
        return Cache::rememberForever($this->key('index'), function () {
            $data = $this->data();
            $names = $data['_meta']['category_names_ar'] ?? [];

            return array_map(fn (string $key) => [
                'key' => $key,
                'count' => count($data[$key] ?? []),
                'name_ar' => (string) ($names[$key] ?? ''),
            ], self::CATEGORIES);
        });
    }

    public function exists(string $category): bool
    {
        return in_array($category, self::CATEGORIES, true);
    }

    /**
     * The adhkar of one category, ready for the page.
     *
     * @return list<array{id: string, arabic: string, count: int, count_desc: string|null, virtue: string|null, meaning_en: string|null, source: string|null, audio: array{url: string, credit: string, credit_url: string}|null}>|null
     */
    public function items(string $category): ?array
    {
        if (! $this->exists($category)) {
            return null;
        }

        return Cache::rememberForever($this->key("cat:$category"), function () use ($category) {
            $items = [];
            foreach ($this->data()[$category] ?? [] as $position => $item) {
                $items[] = $this->present($category, (int) $position, $item);
            }

            return $items;
        });
    }

    public static function dataPath(): string
    {
        return resource_path(self::DATA_PATH);
    }

    /**
     * @param  array<string, mixed>  $item
     * @return array{id: string, arabic: string, count: int, count_desc: string|null, virtue: string|null, meaning_en: string|null, source: string|null, audio: array{url: string, credit: string, credit_url: string}|null}
     */
    private function present(string $category, int $position, array $item): array
    {
        $note = self::clean($item['virtue'] ?? null);
        // Outside morning/evening the "virtue" field holds the English
        // meaning of the dhikr, not a virtue: label it for what it is.
        $isArabic = $note !== null && preg_match('/\p{Arabic}/u', $note) === 1;

        return [
            'id' => $category.'-'.($position + 1),
            'arabic' => (string) ($item['arabic'] ?? ''),
            'count' => max(1, (int) ($item['count'] ?? 1)),
            'count_desc' => self::clean($item['count_desc'] ?? null),
            'virtue' => $isArabic ? $note : null,
            'meaning_en' => $isArabic ? null : $note,
            'source' => self::clean($item['source'] ?? null),
            'audio' => self::audio($category, (string) ($item['audio_file'] ?? '')),
        ];
    }

    /**
     * Where a dhikr's recording streams from (the browser fetches it only
     * after the visitor presses Listen).
     *
     * @return array{url: string, credit: string, credit_url: string}|null
     */
    public static function audio(string $category, string $file): ?array
    {
        if (preg_match('/^\d{1,4}\.mp3$/', $file) !== 1) {
            return null;
        }

        if (in_array($category, self::QURAN_AUDIO_CATEGORIES, true) && in_array($file, self::QURAN_AUDIO, true)) {
            return [
                'url' => 'https://server8.mp3quran.net/afs/'.$file,
                'credit' => 'mp3quran.net — Mishary Alafasy',
                'credit_url' => 'https://mp3quran.net',
            ];
        }

        return [
            'url' => 'https://www.hisnmuslim.com/audio/ar/'.$file,
            'credit' => 'hisnmuslim.com',
            'credit_url' => 'https://www.hisnmuslim.com',
        ];
    }

    private static function clean(mixed $value): ?string
    {
        $value = is_string($value) ? trim($value) : '';

        return $value === '' ? null : $value;
    }

    private function key(string $suffix): string
    {
        $stamp = @filemtime(self::dataPath()) ?: 0;

        return 'adhkar:v'.self::CACHE_VERSION.":$stamp:$suffix";
    }

    /** @return array<string, mixed> */
    private function data(): array
    {
        if ($this->data !== null) {
            return $this->data;
        }

        $data = json_decode((string) @file_get_contents(self::dataPath()), true);
        if (! is_array($data)) {
            throw new RuntimeException('The adhkar library is missing or invalid.');
        }

        return $this->data = $data;
    }
}
