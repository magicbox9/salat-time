<?php

namespace App\Http\Controllers\Hub;

use App\Models\User;
use App\Support\ChosenMosque;
use Illuminate\Auth\Events\Login;
use Illuminate\Http\Request;

/**
 * At sign-in (and right after registration), a mosque chosen as a guest in
 * this browser becomes the account's own mosque when it has none yet.
 *
 * Called by App\Listeners\AdoptGuestMosqueOnLogin; ChosenMosque::for() also
 * adopts on the first page after sign-in.
 */
class AdoptGuestMosque
{
    public function __construct(private readonly Request $request) {}

    public function handle(Login $event): void
    {
        if ($event->user instanceof User && $this->request->hasCookie(ChosenMosque::COOKIE)) {
            ChosenMosque::adopt($this->request, $event->user);
        }
    }
}
