<?php

namespace App\Services\Display;

use App\Models\Mosque;
use App\Models\MosqueDisplayMessage;
use App\Services\PrayerTimes\MosqueTimetable;
use App\Support\MosquePresenter;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Str;

/**
 * Everything a screen needs to run on its own for a week: the mosque, its
 * merged display settings, the active messages, the published times of
 * today and the next six days (so it keeps working offline), Jumu'a, the
 * adhan recordings and the rotation content. Served as
 * GET /mosques/{slug}/display.json and cached for a minute.
 *
 * Its `stamp` changes whenever what the screen shows changes (a manager's
 * edit, a new day, a message starting or ending): screens ask for the stamp
 * every minute (GET /mosques/{slug}/display/stamp.json) and fetch the whole
 * payload again only when it differs.
 */
class DisplayPayload
{
    public const VERSION = 1;

    public const DAYS = 7;

    public function __construct(
        private readonly MosqueTimetable $timetable,
        private readonly RotationContent $content,
        private readonly AdhanCatalog $catalog,
    ) {}

    /** @return array<string, mixed> */
    public function cached(Mosque $mosque): array
    {
        $stamp = $this->stamp($mosque);
        $key = 'display:payload:v'.self::VERSION.":{$mosque->id}:$stamp";

        return Cache::remember($key, (int) config('display.cache_seconds', 60), fn () => $this->build($mosque, $stamp));
    }

    /**
     * Short fingerprint of the manager's last change, the mosque's date and
     * the messages live right now (one small indexed query, no cache).
     */
    public function stamp(Mosque $mosque): string
    {
        $date = CarbonImmutable::now($mosque->timezone)->toDateString();
        $version = (string) Cache::get(self::versionKey($mosque), '0');
        $live = $this->liveMessages($mosque)->pluck('id')->implode(',');

        return substr(hash('sha256', self::VERSION."|$version|$date|$live"), 0, 16);
    }

    /** Makes the next request rebuild the payload (after a manager's change). */
    public static function forget(Mosque $mosque): void
    {
        Cache::forever(self::versionKey($mosque), Str::random(12));
    }

    /** @return array<string, mixed> */
    public function build(Mosque $mosque, ?string $stamp = null): array
    {
        $stamp ??= $this->stamp($mosque);
        $mosque->loadMissing('displaySetting');
        $now = CarbonImmutable::now($mosque->timezone);
        $settingRow = $mosque->displaySetting;

        return [
            'version' => self::VERSION,
            'stamp' => $stamp,
            'generated_at' => $now->toIso8601String(),
            'mosque' => [
                ...MosquePresenter::summary($mosque),
                'tagline' => $mosque->tagline,
                'accent_color' => $mosque->accent_color,
            ],
            'timezone' => $mosque->timezone,
            'today' => $now->toDateString(),
            // An Isha after midnight (far-north summers) still belongs to the evening before.
            'yesterday' => $this->timetable->day($mosque, $now->subDay()),
            'days' => $this->timetable->range($mosque, $now, self::DAYS),
            'jumua' => $this->jumua($mosque),
            'settings' => DisplaySettings::forMosque($mosque),
            'background_url' => $settingRow?->background_path ? asset('storage/'.$settingRow->background_path) : null,
            'catalog' => $this->catalog->list($mosque),
            'messages' => $this->messages($mosque),
            'rotation' => [
                'verses' => $this->content->verses(),
                'adhkar' => $this->content->adhkar(),
                'after_prayer' => $this->content->afterPrayer(),
                'posts' => $this->content->posts($mosque),
            ],
            'labels' => ScreenLabels::all(),
        ];
    }

    /**
     * The mosque's messages being shown right now (within their start/end).
     *
     * @return list<array{id: int, body: string, ends_at: string|null}>
     */
    public function messages(Mosque $mosque): array
    {
        return $this->liveMessages($mosque)
            ->get(['id', 'body', 'ends_at'])
            ->map(fn (MosqueDisplayMessage $message) => [
                'id' => $message->id,
                'body' => $message->body,
                'ends_at' => $message->ends_at?->toIso8601String(),
            ])
            ->values()
            ->all();
    }

    /** @return HasMany<MosqueDisplayMessage, Mosque> */
    private function liveMessages(Mosque $mosque): HasMany
    {
        $now = now();

        return $mosque->displayMessages()
            ->where('active', true)
            ->where(fn (Builder $q) => $q->whereNull('starts_at')->orWhere('starts_at', '<=', $now))
            ->where(fn (Builder $q) => $q->whereNull('ends_at')->orWhere('ends_at', '>', $now))
            ->orderBy('sort')
            ->orderBy('id')
            ->limit((int) config('display.max_messages', 30));
    }

    /** @return array{times: list<string>, as_dhuhr: bool} */
    private function jumua(Mosque $mosque): array
    {
        $asDhuhr = (bool) $mosque->jumua_as_dhuhr;
        $times = $asDhuhr ? [] : array_values(array_filter(
            [$mosque->jumua, $mosque->jumua2, $mosque->jumua3],
            fn ($time) => is_string($time) && MosqueTimetable::minutes($time) !== null,
        ));

        return ['times' => $times, 'as_dhuhr' => $asDhuhr];
    }

    private static function versionKey(Mosque $mosque): string
    {
        return "display:payload-version:{$mosque->id}";
    }
}
