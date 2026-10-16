<?php

namespace Tests\Feature\Hub;

use Tests\TestCase;

/** The hub and globe strings exist in English, French and Arabic, with the same placeholders. */
class HubTranslationsTest extends TestCase
{
    public function test_hub_and_discover_strings_are_translated(): void
    {
        foreach (['hub', 'discover'] as $group) {
            $english = $this->strings('en', $group);
            $this->assertNotEmpty($english);

            foreach (['fr', 'ar'] as $locale) {
                $translated = $this->strings($locale, $group);
                $this->assertEqualsCanonicalizing(array_keys($english), array_keys($translated), "lang/$locale/$group.json keys differ from English");

                foreach ($english as $key => $text) {
                    $this->assertNotSame('', trim((string) $translated[$key]), "$locale: $group.$key is empty");
                    preg_match_all('/\{\w+\}/', $text, $a);
                    preg_match_all('/\{\w+\}/', (string) $translated[$key], $b);
                    $this->assertEqualsCanonicalizing($a[0], $b[0], "$locale: $group.$key placeholders differ");
                }
            }
        }
    }

    /** @return array<string, string> */
    private function strings(string $locale, string $group): array
    {
        return json_decode((string) file_get_contents(lang_path("$locale/$group.json")), true, flags: JSON_THROW_ON_ERROR);
    }
}
