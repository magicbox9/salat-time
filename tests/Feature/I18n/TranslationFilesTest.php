<?php

namespace Tests\Feature\I18n;

use Illuminate\Support\Arr;
use Illuminate\Support\Str;
use Tests\TestCase;

/** French and Arabic translations cover every English key and keep its placeholders. */
class TranslationFilesTest extends TestCase
{
    private const LOCALES = ['fr', 'ar'];

    /** Interface groups owned by the sign-in and settings screens. */
    private const UI_GROUPS = ['auth', 'settings'];

    /** Laravel's server messages (validation errors, sign-in, password reset). */
    private const PHP_GROUPS = ['validation', 'auth', 'passwords', 'pagination'];

    public function test_interface_groups_have_the_same_keys_in_every_language()
    {
        foreach (self::UI_GROUPS as $group) {
            $english = $this->uiStrings('en', $group);
            $this->assertNotEmpty($english, "lang/en/$group.json is empty");

            foreach (self::LOCALES as $locale) {
                $translated = $this->uiStrings($locale, $group);
                $this->assertEqualsCanonicalizing(array_keys($english), array_keys($translated), "lang/$locale/$group.json keys differ from English");

                foreach ($english as $key => $text) {
                    $this->assertNotSame('', trim($translated[$key]), "$locale: $group.$key is empty");
                    $this->assertSame($this->placeholders('/\{\w+\}/', $text), $this->placeholders('/\{\w+\}/', $translated[$key]), "$locale: $group.$key placeholders differ");
                }
            }
        }
    }

    public function test_server_messages_are_translated_for_every_key()
    {
        foreach (self::PHP_GROUPS as $group) {
            $english = $this->serverLines('en', $group);

            foreach (self::LOCALES as $locale) {
                $translated = $this->serverLines($locale, $group);
                $this->assertEqualsCanonicalizing(array_keys($english), array_keys($translated), "lang/$locale/$group.php keys differ from English");

                foreach ($english as $key => $text) {
                    $this->assertSame($this->placeholders('/:[a-z_]+/', $text), $this->placeholders('/:[a-z_]+/', $translated[$key]), "$locale: $group.$key placeholders differ");
                }
            }
        }
    }

    public function test_common_field_names_are_readable()
    {
        foreach (self::LOCALES as $locale) {
            $attributes = require lang_path("$locale/validation.php");

            foreach (['name', 'email', 'password', 'password_confirmation', 'current_password', 'code', 'recovery_code'] as $field) {
                $this->assertNotEmpty($attributes['attributes'][$field] ?? null, "$locale: attributes.$field missing");
            }
        }
    }

    /** @return array<string, string> */
    private function uiStrings(string $locale, string $group): array
    {
        $path = lang_path("$locale/$group.json");
        $this->assertFileExists($path);

        return json_decode((string) file_get_contents($path), true, flags: JSON_THROW_ON_ERROR);
    }

    /** @return array<string, string> Flattened lines, without the per-app "attributes" names. */
    private function serverLines(string $locale, string $group): array
    {
        $path = lang_path("$locale/$group.php");
        $this->assertFileExists($path);

        return Arr::where(Arr::dot(require $path), fn ($value, $key) => ! Str::startsWith($key, 'attributes'));
    }

    /** @return list<string> */
    private function placeholders(string $pattern, string $text): array
    {
        preg_match_all($pattern, $text, $matches);
        $found = array_values(array_unique($matches[0]));
        sort($found);

        return $found;
    }
}
