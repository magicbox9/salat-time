<?php

namespace Tests\Unit\PrayerMethod;

use App\Services\PrayerTimes\Calculation\ConventionTable;
use App\Services\PrayerTimes\Calculation\MosqueMatcher;
use App\Services\PrayerTimes\Calculation\SpecEvaluator;
use App\Services\PrayerTimes\Calculation\TimeZoneClock;
use App\Services\PrayerTimes\Calculation\UnknownSpec;
use DateTimeImmutable;
use DateTimeZone;
use PHPUnit\Framework\TestCase;

/**
 * The method's conformance suite (SPEC §8), ported from
 * final-method/reference/run_vectors.mjs: every one of the 308,520 values in
 * tests/Fixtures/prayer-method must come out exactly. There is no tolerance;
 * a one-minute difference is a bug.
 */
class ConformanceTest extends TestCase
{
    private const FIXTURES = __DIR__.'/../../Fixtures/prayer-method';

    private const DATA = __DIR__.'/../../../resources/prayer-method';

    private static ?ConventionTable $table = null;

    /** @var list<array<string, mixed>> */
    private array $mismatches = [];

    private int $checked = 0;

    public function test_the_data_and_vector_files_are_the_published_ones(): void
    {
        $manifest = self::load(self::DATA.'/MANIFEST.json');
        foreach ($manifest['files'] as $path => $file) {
            $local = str_starts_with($path, 'data/')
                ? self::DATA.'/'.basename($path)
                : self::FIXTURES.'/'.basename($path);
            $this->assertSame($file['sha256'], hash_file('sha256', $local), "{$path} differs from MANIFEST.json");
        }
        $this->assertSame($manifest['methodID'], $this->table()->methodId());
    }

    public function test_engine_vectors(): void
    {
        $this->runDayCases('engine_vectors');
    }

    public function test_family_vectors(): void
    {
        $this->runDayCases('family_vectors');
    }

    public function test_the_departement_table_every_day(): void
    {
        $vectors = self::load(self::FIXTURES.'/table_vectors.json');
        foreach ([...$vectors['departements'], ...$vectors['cities']] as $block) {
            $specs = $this->table()->conventionFor($block['departement']);
            $date = new DateTimeImmutable($block['year'].'-01-01', new DateTimeZone('UTC'));
            foreach (array_keys($block['minutes']['fajr']) as $i) {
                [$y, $m, $d] = array_map('intval', explode('-', $date->format('Y-n-j')));
                $got = SpecEvaluator::computeDay($y, $m, $d, $block['lat'], $block['lon'], $block['tz'], $specs);
                foreach (SpecEvaluator::PRAYERS as $prayer) {
                    $this->check($got[$prayer] === $block['minutes'][$prayer][$i], [
                        'id' => ($block['city'] ?? $block['departement']).' '.$date->format('Y-m-d'),
                        'prayer' => $prayer, 'expected' => $block['minutes'][$prayer][$i], 'got' => $got[$prayer],
                    ]);
                }
                $date = $date->modify('+1 day');
            }
        }
        $this->assertNoMismatches();
    }

    public function test_smoke_values(): void
    {
        $smoke = self::load(self::FIXTURES.'/smoke_values.json');
        $uoif = $this->table()->standardMethod('uoif-safety');
        foreach ($smoke['table'] as $place => $row) {
            foreach ($row['days'] as $date => $values) {
                [$y, $m, $d] = array_map('intval', explode('-', $date));
                $table = SpecEvaluator::computeDay($y, $m, $d, $row['lat'], $row['lon'], 'Europe/Paris', $this->table()->conventionFor($row['department']));
                $plain = SpecEvaluator::computeDay($y, $m, $d, $row['lat'], $row['lon'], 'Europe/Paris', $uoif);
                $this->check(self::clocks($table) === $values, ['id' => "{$place} {$date} table", 'expected' => $values, 'got' => self::clocks($table)]);
                $expected = $smoke['uoif_safety'][$place][$date];
                $this->check(self::clocks($plain) === $expected, ['id' => "{$place} {$date} uoif", 'expected' => $expected, 'got' => self::clocks($plain)]);
            }
        }
        $this->assertNoMismatches();
    }

    public function test_match_my_mosque_vectors(): void
    {
        foreach (self::load(self::FIXTURES.'/match_vectors.json')['cases'] as $case) {
            $default = $this->table()->conventionFor($case['departement']);
            foreach (['fajr', 'isha'] as $prayer) {
                $typed = array_map(function (array $t) {
                    [$y, $m, $d] = array_map('intval', explode('-', $t['date']));

                    return ['y' => $y, 'm' => $m, 'd' => $d, 'minute' => $t['minute']];
                }, $case['typed'][$prayer]);
                $candidates = [$default[$prayer], ...array_column($this->table()->presets($prayer), 'spec')];
                $got = MosqueMatcher::match($prayer, $typed, $case['lat'], $case['lon'], $case['tz'], $candidates);
                $expected = $case['expected'][$prayer];
                $this->check(
                    $got['candidate'] === $expected['candidate'] && $got['adjustment'] === $expected['adjustment'],
                    ['id' => $case['id'], 'prayer' => $prayer, 'expected' => $expected, 'got' => $got],
                );
            }
        }
        $this->assertNoMismatches();
    }

    public function test_postcodes(): void
    {
        foreach (self::load(self::FIXTURES.'/postcode_vectors.json')['cases'] as $case) {
            $got = ConventionTable::departementFromPostcode(is_string($case['postcode']) ? $case['postcode'] : null);
            $this->check($got === $case['departement'], ['id' => json_encode($case['postcode']), 'expected' => $case['departement'], 'got' => $got]);
        }
        $this->assertNoMismatches();
    }

    public function test_unknown_families_and_rules_are_refused(): void
    {
        $specs = $this->table()->standardMethod('mwl');
        $this->expectException(UnknownSpec::class);
        SpecEvaluator::computeDay(2026, 6, 1, 48.85, 2.35, 'Europe/Paris', [...$specs, 'fajr' => ['family' => 'angle', 'angle' => 18, 'rule' => 'GUESS']]);
    }

    /** Engine and family vectors: one day, six prayers, computed with the vector's recorded UTC offset. */
    private function runDayCases(string $file): void
    {
        $zoneDifferences = [];
        foreach (self::load(self::FIXTURES."/{$file}.json")['cases'] as $case) {
            [$y, $m, $d] = array_map('intval', explode('-', $case['date']));
            $recorded = isset($case['utc_offset_hours']) ? (float) $case['utc_offset_hours'] : null;
            if ($recorded !== null && TimeZoneClock::offsetAtLocalNoon($case['tz'], $y, $m, $d) !== $recorded) {
                $zoneDifferences[] = "{$case['tz']} {$case['date']}";
            }
            $got = SpecEvaluator::computeDay($y, $m, $d, $case['lat'], $case['lon'], $case['tz'], $case['specs'], [], $recorded);
            foreach (SpecEvaluator::PRAYERS as $prayer) {
                $this->check($got[$prayer] === $case['expected'][$prayer], [
                    'id' => $case['id'], 'prayer' => $prayer, 'expected' => $case['expected'][$prayer], 'got' => $got[$prayer],
                ]);
            }
        }
        // Time-zone database differences (Casablanca's rules change between tzdata releases) are not engine errors.
        foreach ($zoneDifferences as $difference) {
            $this->assertStringStartsWith('Africa/Casablanca', $difference);
        }
        $this->assertNoMismatches();
    }

    /** @param  array<string, mixed>  $detail */
    private function check(bool $ok, array $detail): void
    {
        $this->checked++;
        if (! $ok && count($this->mismatches) < 20) {
            $this->mismatches[] = $detail;
        }
    }

    private function assertNoMismatches(): void
    {
        $this->assertGreaterThan(0, $this->checked);
        $this->assertSame([], $this->mismatches, "mismatches after {$this->checked} checks");
    }

    /** @param  array<string, int>  $minutes */
    private static function clocks(array $minutes): array
    {
        return array_values(array_map(function (int $minute) {
            $m = (($minute % 1440) + 1440) % 1440;

            return sprintf('%02d:%02d', intdiv($m, 60), $m % 60);
        }, $minutes));
    }

    private function table(): ConventionTable
    {
        return self::$table ??= new ConventionTable(self::DATA);
    }

    /** @return array<string, mixed> */
    private static function load(string $path): array
    {
        return json_decode((string) file_get_contents($path), true, flags: JSON_THROW_ON_ERROR);
    }
}
