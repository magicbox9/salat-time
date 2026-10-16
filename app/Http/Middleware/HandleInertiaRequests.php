<?php

namespace App\Http\Middleware;

use App\Support\Ui;
use Illuminate\Http\Request;
use Inertia\Middleware;

class HandleInertiaRequests extends Middleware
{
    /**
     * The root template that's loaded on the first page visit.
     *
     * @see https://inertiajs.com/server-side-setup#root-template
     *
     * @var string
     */
    protected $rootView = 'app';

    /**
     * Determines the current asset version.
     *
     * @see https://inertiajs.com/asset-versioning
     */
    public function version(Request $request): ?string
    {
        return parent::version($request);
    }

    /**
     * Define the props that are shared by default.
     *
     * @see https://inertiajs.com/shared-data
     *
     * @return array<string, mixed>
     */
    public function share(Request $request): array
    {
        return [
            ...parent::share($request),
            'name' => config('app.name'),
            'auth' => [
                'user' => $request->user(),
                'isAdmin' => (bool) $request->user()?->is_admin,
                'managedMosques' => fn () => $request->user()
                    ? $request->user()->managedMosques()->get(['mosques.slug', 'mosques.name'])
                        ->map(fn ($m) => ['slug' => $m->slug, 'name' => $m->name])->all()
                    : [],
            ],
            'locale' => app()->getLocale(),
            'dir' => Ui::direction(app()->getLocale()),
            'locales' => Ui::LOCALES,
            'ui' => fn () => Ui::strings(app()->getLocale()),
            'sidebarOpen' => ! $request->hasCookie('sidebar_state') || $request->cookie('sidebar_state') === 'true',
        ];
    }
}
