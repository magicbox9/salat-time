<?php

namespace App\Models;

use Database\Factories\MosqueFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

/**
 * A mosque or prayer room. Records come from the research studies (Mawaqit,
 * the mosquee-proche directory, OpenStreetMap) or are created by an admin.
 *
 * @property int $id
 * @property string $slug
 * @property string $name
 * @property float $latitude
 * @property float $longitude
 * @property string $timezone
 * @property Carbon|null $verified_at
 */
#[Fillable([
    'slug', 'name', 'address', 'postcode', 'city', 'country_code', 'territory', 'latitude', 'longitude',
    'timezone', 'association', 'website', 'phone', 'email', 'description', 'logo_path', 'cover_path',
    'source', 'mawaqit_slug', 'mawaqit_id', 'directory_id', 'osm_ref', 'jumua', 'jumua2', 'jumua3',
    'jumua_as_dhuhr', 'verified_at', 'tagline', 'accent_color', 'social_links',
])]
class Mosque extends Model
{
    /** @use HasFactory<MosqueFactory> */
    use HasFactory;

    protected function casts(): array
    {
        return [
            'latitude' => 'float',
            'longitude' => 'float',
            'jumua_as_dhuhr' => 'boolean',
            'verified_at' => 'datetime',
            'social_links' => 'array',
        ];
    }

    protected static function booted(): void
    {
        static::saving(function (Mosque $mosque) {
            $mosque->search_name = static::searchKey($mosque->name.' '.$mosque->city);
        });
    }

    /** Lowercase, accent-free text used for fuzzy matching. */
    public static function searchKey(?string $text): string
    {
        return Str::of((string) $text)->ascii()->lower()->squish()->limit(250, '')->toString();
    }

    public function getRouteKeyName(): string
    {
        return 'slug';
    }

    public function calendars(): HasMany
    {
        return $this->hasMany(MosquePrayerCalendar::class);
    }

    public function managers(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'mosque_managers')->withPivot('role')->withTimestamps();
    }

    public function claims(): HasMany
    {
        return $this->hasMany(MosqueClaim::class);
    }

    public function posts(): HasMany
    {
        return $this->hasMany(MosquePost::class);
    }

    public function postCategories(): HasMany
    {
        return $this->hasMany(MosquePostCategory::class)->orderBy('sort')->orderBy('name');
    }

    public function pages(): HasMany
    {
        return $this->hasMany(MosquePage::class);
    }

    public function displaySetting(): HasOne
    {
        return $this->hasOne(MosqueDisplaySetting::class);
    }

    public function displayMessages(): HasMany
    {
        return $this->hasMany(MosqueDisplayMessage::class);
    }

    public function payoutMethods(): HasMany
    {
        return $this->hasMany(MosquePayoutMethod::class);
    }

    public function campaigns(): HasMany
    {
        return $this->hasMany(Campaign::class);
    }

    public function isVerified(): bool
    {
        return $this->verified_at !== null;
    }

    public function mawaqitUrl(): ?string
    {
        return $this->mawaqit_slug ? 'https://mawaqit.net/fr/'.$this->mawaqit_slug : null;
    }

    public function googleMapsUrl(): string
    {
        return 'https://www.google.com/maps/search/?api=1&query='.$this->latitude.','.$this->longitude;
    }

    /**
     * Mosques within $radiusKm of a point, nearest first, with `distance_m`.
     *
     * @param  Builder<Mosque>  $query
     */
    public function scopeNear(Builder $query, float $lat, float $lng, float $radiusKm = 25): Builder
    {
        $point = 'll_to_earth(?, ?)';
        $here = 'll_to_earth(latitude::float8, longitude::float8)';

        return $query
            ->select('mosques.*')
            ->selectRaw("earth_distance($point, $here) AS distance_m", [$lat, $lng])
            ->whereRaw("earth_box($point, ?) @> $here", [$lat, $lng, $radiusKm * 1000])
            ->whereRaw("earth_distance($point, $here) <= ?", [$lat, $lng, $radiusKm * 1000])
            ->orderBy('distance_m');
    }

    /**
     * Fuzzy name / city search.
     *
     * @param  Builder<Mosque>  $query
     */
    public function scopeSearch(Builder $query, string $term): Builder
    {
        $key = static::searchKey($term);

        return $query
            ->where(fn (Builder $q) => $q->where('search_name', 'like', '%'.addcslashes($key, '%_\\').'%')
                ->orWhereRaw('search_name % ?', [$key]))
            ->orderByRaw('similarity(search_name, ?) DESC', [$key]);
    }
}
