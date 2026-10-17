<?php

namespace App\Listeners;

use App\Http\Controllers\Hub\AdoptGuestMosque;
use Illuminate\Auth\Events\Login;

/**
 * At sign-in, a mosque chosen as a guest becomes the account's own mosque
 * (see AdoptGuestMosque). Lives here so Laravel discovers it automatically,
 * also when routes are cached.
 */
class AdoptGuestMosqueOnLogin
{
    public function __construct(private readonly AdoptGuestMosque $adopt) {}

    public function handle(Login $event): void
    {
        $this->adopt->handle($event);
    }
}
