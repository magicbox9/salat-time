<?php

namespace App\Services\PrayerTimes\Calculation;

use RuntimeException;

/**
 * The method's data files (resources/prayer-method, copied verbatim from
 * "Prayer Times Study/final-method/data"): the département table, the
 * standard methods and the "Match my mosque" presets, plus the rules that
 * pick the right specs for a place (SPEC §4, INTEGRATION §2).
 */
final class ConventionTable
{
    public const FILES = ['france_conventions_v1.json', 'standard_methods.json', 'match_presets.json'];

    /** @var array<string, mixed> */
    private array $table;

    /** @var array<string, array<string, array<string, mixed>>|null> specs by method id */
    private array $methods = [];

    /** @var array<string, list<array<string, mixed>>> */
    private array $presets;

    public function __construct(?string $directory = null)
    {
        $directory ??= resource_path('prayer-method');
        $this->table = self::read($directory.'/france_conventions_v1.json');
        foreach (self::read($directory.'/standard_methods.json')['methods'] as $method) {
            $this->methods[$method['id']] = $method['specs'];
        }
        $this->presets = self::read($directory.'/match_presets.json')['presets'];
    }

    /** The data file's identity ("fr-dept-2026.1"); cached timetables are tied to it. */
    public function methodId(): string
    {
        return (string) $this->table['methodID'];
    }

    /** "75001" → "75", "20090" → "2A"; overseas, Monaco and anything not 5 digits → null. */
    public static function departementFromPostcode(?string $postcode): ?string
    {
        $code = preg_replace('/\s+/', '', (string) $postcode);
        if (! preg_match('/^\d{5}$/', $code) || str_starts_with($code, '97') || str_starts_with($code, '98')) {
            return null;
        }
        if (str_starts_with($code, '20')) {
            return (int) $code < 20200 ? '2A' : '2B';
        }

        return substr($code, 0, 2);
    }

    /**
     * The six specs a département's mosques usually follow; an unknown or
     * missing département gets the national fallback.
     *
     * @return array<string, array<string, mixed>>
     */
    public function conventionFor(?string $departement): array
    {
        $entry = $departement !== null ? ($this->table['departments'][$departement] ?? null) : null;
        $specs = [];
        foreach (SpecEvaluator::PRAYERS as $prayer) {
            $index = $entry ? $entry[$prayer] : $this->table['national'][$prayer];
            $specs[$prayer] = $this->table['specs'][$prayer][$index];
        }

        return $specs;
    }

    public function knowsDepartement(?string $departement): bool
    {
        return $departement !== null && isset($this->table['departments'][$departement]);
    }

    /**
     * A standard method's specs ("mwl", "uoif-safety", …); null for an unknown
     * id or for "fr-dept", which is the table itself.
     *
     * @return array<string, array<string, mixed>>|null
     */
    public function standardMethod(string $id): ?array
    {
        return $this->methods[$id] ?? null;
    }

    /** @return list<array{id: string, label: string, spec: array<string, mixed>}> */
    public function presets(string $prayer): array
    {
        return $this->presets[$prayer] ?? [];
    }

    /**
     * The convention at a place. Metropolitan France uses the département
     * table (or, when the owner switched it off, UOIF 12° with safety
     * minutes); everywhere else, the standard method for outside France.
     *
     * @param  string|null  $territory  "FR" for metropolitan France, else an overseas or foreign code
     */
    public function forPlace(?string $territory, ?string $postcode, bool $useTable = true, string $elsewhere = 'mwl'): PlaceConvention
    {
        if (strtoupper((string) $territory) !== 'FR') {
            return $this->standard($elsewhere);
        }
        if (! $useTable) {
            return $this->standard('uoif-safety');
        }
        $departement = self::departementFromPostcode($postcode);
        if ($this->knowsDepartement($departement)) {
            return new PlaceConvention(PlaceConvention::FRANCE_DEPARTEMENT, $departement, $this->conventionFor($departement), $this->methodId());
        }

        return new PlaceConvention(PlaceConvention::FRANCE_NATIONAL, null, $this->conventionFor(null), $this->methodId());
    }

    private function standard(string $id): PlaceConvention
    {
        $specs = $this->standardMethod($id) ?? throw new UnknownSpec("unknown standard method {$id}");

        return new PlaceConvention($id, null, $specs, $this->methodId());
    }

    /** @return array<string, mixed> */
    private static function read(string $path): array
    {
        $json = @file_get_contents($path);
        if ($json === false) {
            throw new RuntimeException("Prayer method data missing: {$path}");
        }

        return json_decode($json, true, flags: JSON_THROW_ON_ERROR);
    }
}
