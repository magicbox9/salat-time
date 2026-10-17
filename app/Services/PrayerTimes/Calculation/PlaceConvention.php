<?php

namespace App\Services\PrayerTimes\Calculation;

/**
 * The calculation rules that apply at one place: which method, the
 * département it comes from (when the département table applies) and the six
 * prayer specs.
 */
final class PlaceConvention
{
    /** The département table of metropolitan France. */
    public const FRANCE_DEPARTEMENT = 'fr-dept';

    /** The table's national fallback (metropolitan France, no usable postcode). */
    public const FRANCE_NATIONAL = 'fr-national';

    /**
     * @param  string  $method  self::FRANCE_* or a standard method id ("uoif-safety", "mwl", …)
     * @param  array<string, array<string, mixed>>  $specs  keyed by SpecEvaluator::PRAYERS
     */
    public function __construct(
        public readonly string $method,
        public readonly ?string $departement,
        public readonly array $specs,
        public readonly string $version,
    ) {}

    /** @return array{id: string, departement: string|null, version: string} */
    public function toArray(): array
    {
        return ['id' => $this->method, 'departement' => $this->departement, 'version' => $this->version];
    }
}
