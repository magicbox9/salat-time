<?php

namespace App\Services\Fundraising;

use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Model;

/** A date attribute of a model (cast by the model), or null when it is empty. */
final class ModelDate
{
    public static function of(Model $model, string $attribute): ?CarbonInterface
    {
        $value = $model->getAttribute($attribute);

        return $value instanceof CarbonInterface ? $value : null;
    }

    public static function iso(Model $model, string $attribute): ?string
    {
        return self::of($model, $attribute)?->toIso8601String();
    }
}
