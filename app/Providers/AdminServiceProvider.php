<?php

namespace App\Providers;

use App\Http\Controllers\Claims\ClaimDocumentPruner;
use App\Models\MosqueClaim;
use App\Models\User;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

/**
 * Platform administration: who is an admin, who may read a claim's
 * supporting document, and the rate limits of the claim / admin endpoints.
 * Every decision is read from the database (users.is_admin, mosque_claims).
 */
class AdminServiceProvider extends ServiceProvider
{
    public const PRUNE_DOCUMENTS_TASK = 'claims:prune-documents';

    public function boot(): void
    {
        Gate::define('admin', fn (User $user): bool => $user->is_admin === true);

        // A claim's document is private: only platform admins and the person who sent it.
        Gate::define('view-claim-document', fn (User $user, MosqueClaim $claim): bool => $user->is_admin === true || $claim->user_id === $user->id);

        $key = fn (Request $request): string => (string) ($request->user()?->getAuthIdentifier() ?? $request->ip());

        RateLimiter::for('claims-submit', fn (Request $request) => [
            Limit::perMinute(3)->by('claims-submit:m:'.$key($request)),
            Limit::perDay(20)->by('claims-submit:d:'.$key($request)),
        ]);
        RateLimiter::for('claims-document', fn (Request $request) => Limit::perMinute(30)->by('claims-document:'.$key($request)));
        RateLimiter::for('admin-write', fn (Request $request) => Limit::perMinute(60)->by('admin-write:'.$key($request)));

        // Documents of deleted claims (account or mosque removed) do not outlive them.
        $this->callAfterResolving(Schedule::class, function (Schedule $schedule): void {
            $schedule->call(new ClaimDocumentPruner)
                ->daily()
                ->name(self::PRUNE_DOCUMENTS_TASK)
                ->withoutOverlapping();
        });
    }
}
