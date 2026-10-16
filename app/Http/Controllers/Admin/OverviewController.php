<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Claims\ClaimPresenter;
use App\Models\Mosque;
use App\Models\MosqueClaim;
use App\Models\MosquePost;
use App\Models\PostComment;
use App\Models\User;
use Inertia\Response;

/** /admin — platform figures and the claims waiting for a decision. */
class OverviewController extends AdminController
{
    public function __invoke(): Response
    {
        $pending = MosqueClaim::query()
            ->where('status', MosqueClaim::PENDING)
            ->with(['mosque:id,slug,name,city,verified_at', 'user:id,name,email'])
            ->oldest()
            ->limit(6)
            ->get()
            ->map(fn (MosqueClaim $claim) => ClaimPresenter::forAdminList($claim))
            ->all();

        return $this->page('admin/index', [
            'stats' => [
                'mosques' => Mosque::query()->count(),
                'mosques_with_times' => Mosque::query()->has('calendars')->count(),
                'mosques_verified' => Mosque::query()->whereNotNull('verified_at')->count(),
                'users' => User::query()->count(),
                'managers' => User::query()->has('managedMosques')->count(),
                'admins' => User::query()->where('is_admin', true)->count(),
                'claims_pending' => MosqueClaim::query()->where('status', MosqueClaim::PENDING)->count(),
                'posts' => MosquePost::query()->count(),
                'comments' => PostComment::query()->count(),
            ],
            'pendingClaims' => $pending,
        ]);
    }
}
