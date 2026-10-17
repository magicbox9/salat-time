<?php

namespace Tests\Feature\Fundraising;

use Tests\TestCase;

/** Every fundraising string exists in French and Arabic, with the same {placeholders}. */
class FundraisingTranslationsTest extends TestCase
{
    public function test_french_and_arabic_cover_every_english_key(): void
    {
        $english = $this->strings('en');
        $this->assertNotEmpty($english);

        foreach (['fr', 'ar'] as $locale) {
            $translated = $this->strings($locale);
            $this->assertEqualsCanonicalizing(array_keys($english), array_keys($translated), "lang/$locale/fundraising.json keys differ from English");

            foreach ($english as $key => $text) {
                $this->assertNotSame('', trim($translated[$key]), "$locale: fundraising.$key is empty");
                $this->assertSame($this->placeholders($text), $this->placeholders($translated[$key]), "$locale: fundraising.$key placeholders differ");
            }
        }
    }

    /** @return array<string, string> */
    private function strings(string $locale): array
    {
        return json_decode((string) file_get_contents(lang_path("$locale/fundraising.json")), true, flags: JSON_THROW_ON_ERROR);
    }

    /** @return list<string> */
    private function placeholders(string $text): array
    {
        preg_match_all('/\{\w+\}/', $text, $matches);
        $found = array_values(array_unique($matches[0]));
        sort($found);

        return $found;
    }
}
