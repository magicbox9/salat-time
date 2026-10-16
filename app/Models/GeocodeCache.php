<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['query_hash', 'query', 'provider', 'results'])]
class GeocodeCache extends Model
{
    protected $table = 'geocode_cache';

    protected function casts(): array
    {
        return ['results' => 'array'];
    }
}
