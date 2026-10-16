<?php

namespace App\Http\Controllers\MosquePage\Support;

use DateTimeImmutable;
use Illuminate\Pagination\Cursor;
use Illuminate\Validation\ValidationException;

/**
 * A "Load more" cursor, accepted only when it carries exactly the columns the
 * list is ordered by, each with a value of the right type. Cursors come from
 * the visitor: a forged one would otherwise reach PostgreSQL as an invalid
 * timestamp or bigint, or name a missing column, and fail with a 500.
 */
final class FeedCursor
{
    public const ID = 'id';

    public const TIMESTAMP = 'timestamp';

    /**
     * @param  array<string, self::ID|self::TIMESTAMP>  $columns  order columns => expected kind
     *
     * @throws ValidationException
     */
    public static function decode(?string $encoded, array $columns): ?Cursor
    {
        if ($encoded === null || $encoded === '') {
            return null;
        }

        $cursor = Cursor::fromEncoded($encoded);
        $parameters = $cursor?->toArray() ?? [];
        $pointsToNext = $parameters['_pointsToNextItems'] ?? null;
        unset($parameters['_pointsToNextItems']);

        $valid = $cursor !== null
            && is_bool($pointsToNext)
            && array_diff_key($parameters, $columns) === []
            && array_diff_key($columns, $parameters) === [];

        foreach ($columns as $name => $kind) {
            $valid = $valid && self::matches($kind, $parameters[$name]);
        }

        if (! $valid) {
            throw ValidationException::withMessages(['cursor' => ui('mosque.invalid_cursor')]);
        }

        return $cursor;
    }

    private static function matches(string $kind, mixed $value): bool
    {
        if ($kind === self::ID) {
            return is_int($value) && $value > 0;
        }

        // Laravel writes timestamps as "Y-m-d H:i:s" (Carbon's string form).
        $date = is_string($value) ? DateTimeImmutable::createFromFormat('!Y-m-d H:i:s', $value) : false;

        return $date !== false && $date->format('Y-m-d H:i:s') === $value;
    }
}
