<?php

namespace App\Http\Controllers\MosquePage\Support;

/**
 * Validation for free text people write on a mosque page (comments, posts,
 * page details): valid UTF-8 without NUL bytes. PostgreSQL refuses anything
 * else, so without this rule a malformed form field would end in a 500.
 */
final class PlainText
{
    public const RULE = 'regex:/^[^\x00]*$/u';
}
