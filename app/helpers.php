<?php

use App\Support\Ui;

if (! function_exists('ui')) {
    /** Translated interface string, e.g. ui('claims.submitted'). */
    function ui(string $key, array $replace = []): string
    {
        return Ui::t($key, $replace);
    }
}
