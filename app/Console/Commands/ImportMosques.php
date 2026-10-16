<?php

namespace App\Console\Commands;

use App\Models\Mosque;
use App\Models\MosquePrayerCalendar;
use Carbon\CarbonImmutable;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Loads the mosques gathered in the research studies (Prayer Times Study/):
 *  1. study 3 MAWAQIT page snapshots — name, position, published yearly calendar, iqama, Jumu'a;
 *     addresses come from the study 3 register;
 *  2. study 3 register rows from the mosquee-proche directory that have no MAWAQIT page;
 *  3. study 1 OpenStreetMap mosques not already present.
 * Records closer than a few dozen metres to one already imported are treated as the same mosque.
 * Re-running updates existing records (matched by MAWAQIT slug, directory id or OSM id).
 */
#[Signature('mosques:import {--path=/data/studies : Folder that holds "study 1" and "study 3"}')]
#[Description('Import the studied mosques of France and their published prayer calendars')]
class ImportMosques extends Command
{
    private const SAME_PLACE_METRES = 60;

    /** @var array<string, list<array{0: float, 1: float}>> */
    private array $grid = [];

    /** @var array<string, true> */
    private array $slugs = [];

    public function handle(): int
    {
        $root = rtrim((string) $this->option('path'), '/');
        $study3 = "$root/study 3/France_Prayer_Times_Research_Data";
        $register = $this->readRegister("$study3/data/mosque_register.csv");
        if ($register === null) {
            $this->error("Register not found under $study3 (is STUDIES_PATH mounted?)");

            return self::FAILURE;
        }
        foreach (Mosque::query()->get(['slug', 'latitude', 'longitude']) as $m) {
            $this->slugs[$m->slug] = true;
            $this->remember($m->latitude, $m->longitude);
        }

        $mawaqit = $this->importSnapshots("$study3/source_snapshots/mawaqit", $register['bySlug']);
        $directory = $this->importDirectory($register['rows']);
        $osm = $this->importOsm("$root/study 1/data/osm_mosques_france.json");

        $this->info("MAWAQIT mosques: $mawaqit · directory-only: $directory · OpenStreetMap-only: $osm");
        $this->info('Mosques in database: '.Mosque::count().' · with published times: '.MosquePrayerCalendar::count());

        return self::SUCCESS;
    }

    /** @return array{rows: list<array<string, string>>, bySlug: array<string, array<string, string>>}|null */
    private function readRegister(string $path): ?array
    {
        if (! is_file($path)) {
            return null;
        }
        $handle = fopen($path, 'r');
        $header = array_map(fn ($h) => trim($h, "\u{FEFF} "), fgetcsv($handle, escape: '\\'));
        $rows = [];
        $bySlug = [];
        while (($line = fgetcsv($handle, escape: '\\')) !== false) {
            if (count($line) !== count($header)) {
                continue;
            }
            $row = array_combine($header, $line);
            if (str_contains($row['quality_flags'] ?? '', 'Possible test record')) {
                continue;
            }
            $rows[] = $row;
            if ($row['mawaqit_slug'] !== '' && ! isset($bySlug[$row['mawaqit_slug']])) {
                $bySlug[$row['mawaqit_slug']] = $row;
            }
        }
        fclose($handle);

        return ['rows' => $rows, 'bySlug' => $bySlug];
    }

    /** @param  array<string, array<string, string>>  $register */
    private function importSnapshots(string $folder, array $register): int
    {
        $files = glob("$folder/*.json") ?: [];
        $bar = $this->output->createProgressBar(count($files));
        $count = 0;
        foreach ($files as $file) {
            $bar->advance();
            $conf = json_decode((string) file_get_contents($file), true);
            if (! is_array($conf) || empty($conf['slug']) || ! isset($conf['latitude'], $conf['longitude'])) {
                continue;
            }
            $reg = $register[$conf['slug']] ?? [];
            DB::transaction(function () use ($conf, $reg, &$count) {
                $mosque = Mosque::query()->firstOrNew(['mawaqit_slug' => $conf['slug']]);
                $mosque->fill([
                    'name' => Str::limit(trim((string) $conf['name']), 195, ''),
                    'address' => $this->addressLine($reg['address'] ?? null),
                    'postcode' => $reg['postcode'] ?? null ?: null,
                    'city' => $this->cityName($reg['city'] ?? null),
                    'country_code' => strtoupper(substr((string) ($conf['countryCode'] ?? 'FR'), 0, 2)) ?: 'FR',
                    'territory' => ($reg['territory'] ?? '') ?: null,
                    'latitude' => (float) $conf['latitude'],
                    'longitude' => (float) $conf['longitude'],
                    'timezone' => $this->timezone($conf['timezone'] ?? null),
                    'association' => Str::limit(trim((string) ($conf['association'] ?? '')), 195, '') ?: null,
                    'website' => $this->url($conf['site'] ?? null),
                    'source' => 'mawaqit',
                    'mawaqit_id' => $conf['mosque_id'] ?? null,
                    'directory_id' => ($reg['directory_id'] ?? '') ?: null,
                    'jumua' => $this->hhmm($conf['jumua'] ?? null),
                    'jumua2' => $this->hhmm($conf['jumua2'] ?? null),
                    'jumua3' => $this->hhmm($conf['jumua3'] ?? null),
                    'jumua_as_dhuhr' => (bool) ($conf['jumuaAsDuhr'] ?? false),
                ]);
                if (! $mosque->exists) {
                    // MAWAQIT page addresses are readable even for Arabic names.
                    $mosque->slug = $this->uniqueSlug($conf['slug'], null);
                    $this->remember($mosque->latitude, $mosque->longitude);
                }
                $mosque->save();

                $days = $this->months($conf['calendar'] ?? null, 6);
                if ($days) {
                    $retrieved = isset($conf['retrieved_utc']) ? CarbonImmutable::parse($conf['retrieved_utc']) : now();
                    MosquePrayerCalendar::query()->updateOrCreate(
                        ['mosque_id' => $mosque->id, 'year' => (int) $retrieved->year],
                        [
                            'source' => 'mawaqit',
                            'timezone' => $mosque->timezone,
                            'days' => $days,
                            'iqama' => $this->months($conf['iqamaCalendar'] ?? null, 5),
                            'imsak_minutes' => isset($conf['imsakNbMinBeforeFajr']) ? (int) $conf['imsakNbMinBeforeFajr'] : null,
                            'retrieved_at' => $retrieved,
                        ],
                    );
                }
                $count++;
            });
        }
        $bar->finish();
        $this->newLine();

        return $count;
    }

    /** @param  list<array<string, string>>  $rows */
    private function importDirectory(array $rows): int
    {
        $count = 0;
        foreach ($rows as $row) {
            if ($row['mawaqit_slug'] !== '' || $row['directory_id'] === '' || $row['lat'] === '') {
                continue;
            }
            $lat = (float) $row['lat'];
            $lng = (float) $row['lng'];
            $existing = Mosque::query()->where('directory_id', $row['directory_id'])->first();
            if (! $existing && $this->isKnownPlace($lat, $lng)) {
                continue;
            }
            $mosque = $existing ?? new Mosque;
            $mosque->fill([
                'name' => Str::limit(trim($row['name']) ?: 'Mosquée', 195, ''),
                'address' => $this->addressLine($row['address']),
                'postcode' => $row['postcode'] ?: null,
                'city' => $this->cityName($row['city']),
                'country_code' => 'FR',
                'territory' => $row['territory'] ?: null,
                'latitude' => $lat,
                'longitude' => $lng,
                'timezone' => $this->territoryTimezone($row['territory']),
                'website' => $this->url($row['mosque_website'] ?? null),
                'source' => 'directory',
                'directory_id' => $row['directory_id'],
            ]);
            if (! $mosque->exists) {
                $mosque->slug = $this->uniqueSlug($mosque->name, $mosque->city);
                $this->remember($lat, $lng);
            }
            $mosque->save();
            $count++;
        }

        return $count;
    }

    private function importOsm(string $path): int
    {
        if (! is_file($path)) {
            $this->warn("OpenStreetMap list not found at $path — skipped.");

            return 0;
        }
        $count = 0;
        foreach (json_decode((string) file_get_contents($path), true) ?: [] as $o) {
            $lat = (float) $o['lat'];
            $lng = (float) $o['lon'];
            $existing = Mosque::query()->where('osm_ref', $o['osm'])->first();
            if (! $existing && $this->isKnownPlace($lat, $lng, 120)) {
                continue;
            }
            $tags = $o['tags'] ?? [];
            $city = $o['commune'] ?? ($tags['addr:city'] ?? null);
            $street = trim(($tags['addr:housenumber'] ?? '').' '.($tags['addr:street'] ?? ''));
            $mosque = $existing ?? new Mosque;
            $mosque->fill([
                'name' => Str::limit(trim((string) ($tags['name'] ?? '')) ?: 'Mosquée', 195, ''),
                'address' => $street !== '' ? $street : null,
                'postcode' => $tags['addr:postcode'] ?? (($o['postcodes'][0] ?? null) ?: null),
                'city' => $this->cityName($city),
                'country_code' => 'FR',
                'territory' => ($o['region'] ?? '') === 'Outre-mer' ? $this->territoryFromDep((string) ($o['dep'] ?? '')) : 'FR',
                'latitude' => $lat,
                'longitude' => $lng,
                'timezone' => $this->territoryTimezone($this->territoryFromDep((string) ($o['dep'] ?? ''))),
                'website' => $this->url($tags['website'] ?? ($tags['contact:website'] ?? null)),
                'phone' => isset($tags['phone']) ? Str::limit($tags['phone'], 38, '') : null,
                'source' => 'osm',
                'osm_ref' => $o['osm'],
            ]);
            if (! $mosque->exists) {
                $mosque->slug = $this->uniqueSlug($mosque->name, $mosque->city);
                $this->remember($lat, $lng);
            }
            $mosque->save();
            $count++;
        }

        return $count;
    }

    /**
     * MAWAQIT calendars: 12 objects keyed "1".."31" (or lists). Rows with seven
     * values carry an extra Sabah slot after Fajr, which is dropped.
     *
     * @return list<list<list<string>>>|null
     */
    private function months(mixed $calendar, int $width): ?array
    {
        if (! is_array($calendar) || count($calendar) !== 12) {
            return null;
        }
        $out = [];
        foreach ($calendar as $month) {
            if (! is_array($month)) {
                return null;
            }
            if (! array_is_list($month)) {
                ksort($month, SORT_NUMERIC);
            }
            $rows = [];
            foreach (array_values($month) as $row) {
                $row = array_values(array_map('strval', (array) $row));
                if ($width === 6 && count($row) === 7) {
                    array_splice($row, 1, 1);
                }
                $rows[] = array_slice($row, 0, $width);
            }
            $out[] = $rows;
        }

        return $out;
    }

    private function isKnownPlace(float $lat, float $lng, int $metres = self::SAME_PLACE_METRES): bool
    {
        foreach ($this->cells($lat, $lng) as $cell) {
            foreach ($this->grid[$cell] ?? [] as [$a, $b]) {
                $dy = ($lat - $a) * 111320;
                $dx = ($lng - $b) * 111320 * cos(deg2rad($lat));
                if (sqrt($dx * $dx + $dy * $dy) <= $metres) {
                    return true;
                }
            }
        }

        return false;
    }

    private function remember(float $lat, float $lng): void
    {
        $this->grid[$this->cell($lat, $lng)][] = [$lat, $lng];
    }

    private function cell(float $lat, float $lng): string
    {
        return floor($lat * 200).':'.floor($lng * 200);
    }

    /** @return list<string> */
    private function cells(float $lat, float $lng): array
    {
        $out = [];
        for ($i = -1; $i <= 1; $i++) {
            for ($j = -1; $j <= 1; $j++) {
                $out[] = (floor($lat * 200) + $i).':'.(floor($lng * 200) + $j);
            }
        }

        return $out;
    }

    private function uniqueSlug(string $name, ?string $city): string
    {
        // Keep the Latin part of mixed Arabic/Latin names; add the city unless the name has it.
        $latin = trim(preg_replace('/[^\p{Latin}\p{N}\s\'’-]+/u', ' ', $name));
        $words = preg_match_all('/\p{Latin}/u', $latin) >= 3 ? $latin : 'mosquee';
        $withCity = $city && ! str_contains(Mosque::searchKey($words), Mosque::searchKey($city)) ? "$words $city" : $words;
        $base = Str::limit(Str::slug($withCity), 140, '') ?: 'mosquee';
        $slug = $base;
        for ($i = 2; isset($this->slugs[$slug]); $i++) {
            $slug = "$base-$i";
        }
        $this->slugs[$slug] = true;

        return $slug;
    }

    private function addressLine(?string $address): ?string
    {
        $address = trim(preg_replace('/\s+France$/u', '', (string) $address));

        return $address !== '' ? Str::limit($address, 295, '') : null;
    }

    private function cityName(?string $city): ?string
    {
        $city = trim((string) $city);
        if ($city === '') {
            return null;
        }

        return mb_strtoupper($city) === $city ? Str::title(mb_strtolower($city)) : $city;
    }

    private function url(?string $url): ?string
    {
        $url = trim((string) $url);

        return filter_var($url, FILTER_VALIDATE_URL) && preg_match('#^https?://#', $url) ? Str::limit($url, 295, '') : null;
    }

    private function hhmm(mixed $value): ?string
    {
        return is_string($value) && preg_match('/^\d{1,2}:\d{2}$/', $value) ? str_pad($value, 5, '0', STR_PAD_LEFT) : null;
    }

    private function timezone(?string $tz): string
    {
        return $tz && in_array($tz, timezone_identifiers_list(), true) && $tz !== 'UTC' ? $tz : 'Europe/Paris';
    }

    private function territoryTimezone(?string $territory): string
    {
        return match ($territory) {
            'YT' => 'Indian/Mayotte',
            'RE' => 'Indian/Reunion',
            'GP' => 'America/Guadeloupe',
            'MQ' => 'America/Martinique',
            'GF' => 'America/Cayenne',
            'NC' => 'Pacific/Noumea',
            default => 'Europe/Paris',
        };
    }

    private function territoryFromDep(string $dep): string
    {
        return ['971' => 'GP', '972' => 'MQ', '973' => 'GF', '974' => 'RE', '976' => 'YT'][$dep] ?? 'FR';
    }
}
