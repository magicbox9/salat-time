<?php

namespace App\Http\Requests\Manage;

use App\Models\Mosque;

/**
 * Form requests of the management area: only the mosque's managers (or an
 * admin), as stored in the database (MosquePolicy@manage).
 */
trait AuthorizesMosqueManagers
{
    public function authorize(): bool
    {
        $mosque = $this->route('mosque');

        return $mosque instanceof Mosque && (bool) $this->user()?->can('manage', $mosque);
    }

    protected function mosque(): Mosque
    {
        /** @var Mosque $mosque */
        $mosque = $this->route('mosque');

        return $mosque;
    }
}
