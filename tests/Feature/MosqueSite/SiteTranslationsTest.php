<?php

namespace Tests\Feature\MosqueSite;

use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

/**
 * Every string of the mosque sites and their management exists in English,
 * French and Arabic, with the same {placeholders}.
 */
class SiteTranslationsTest extends TestCase
{
    /** @return array<string, array{string}> */
    public static function translationGroups(): array
    {
        return ['mosquesite' => ['mosquesite'], 'manage' => ['manage'], 'mosque' => ['mosque']];
    }

    #[DataProvider('translationGroups')]
    public function test_every_key_is_translated_with_the_same_placeholders(string $group): void
    {
        $strings = [];
        foreach (['en', 'fr', 'ar'] as $locale) {
            $strings[$locale] = json_decode((string) file_get_contents(lang_path("$locale/$group.json")), true, flags: JSON_THROW_ON_ERROR);
        }

        foreach (['fr', 'ar'] as $locale) {
            $this->assertSame([], array_values(array_diff(array_keys($strings['en']), array_keys($strings[$locale]))), "$locale/$group.json lacks keys");
            $this->assertSame([], array_values(array_diff(array_keys($strings[$locale]), array_keys($strings['en']))), "$locale/$group.json has extra keys");

            foreach ($strings['en'] as $key => $english) {
                $this->assertNotSame('', trim((string) $strings[$locale][$key]), "$locale: $group.$key is empty");
                $this->assertSame($this->placeholders($english), $this->placeholders($strings[$locale][$key]), "$locale: $group.$key placeholders");
            }
        }
    }

    /** @return list<string> */
    private function placeholders(string $text): array
    {
        preg_match_all('/\{([a-z_]+)\}/', $text, $matches);
        $names = array_values(array_unique($matches[1]));
        sort($names);

        return $names;
    }
}
