<?php

namespace App\Http\Controllers\Admin\Fundraising;

use App\Http\Controllers\Admin\AdminController;
use App\Models\Mosque;
use App\Models\MosquePayoutMethod;
use App\Notifications\PayoutVerified;
use App\Services\Fundraising\FundraisingMail;
use App\Services\Fundraising\PayoutPresenter;
use App\Services\Fundraising\ReviewVersion;
use App\Services\Payments\BankAccount;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Inertia\Inertia;
use Inertia\Response;

/**
 * /admin/fundraising/payouts — the mosques' own accounts, verified by an
 * admin before any donation can reach them. The full IBAN is shown only on
 * an explicit request, and who saw it or verified it is logged.
 */
class PayoutReviewController extends AdminController
{
    public function index(Request $request): Response
    {
        $state = $this->choice($request, 'state', ['to_verify', 'verified', 'all']) ?? 'to_verify';
        $query = MosquePayoutMethod::query()
            ->when($state === 'to_verify', fn (Builder $q) => $q->whereNull('verified_at'))
            ->when($state === 'verified', fn (Builder $q) => $q->whereNotNull('verified_at'))
            ->with(['mosque:id,slug,name,city,verified_at'])
            ->leftJoin('users as verifiers', 'verifiers.id', '=', 'mosque_payout_methods.verified_by')
            ->select('mosque_payout_methods.*', 'verifiers.name as verifier_name')
            ->orderBy('mosque_payout_methods.updated_at');

        return $this->page('admin/fundraising/payouts', [
            'payouts' => $this->paginated($query->paginate(25)->withQueryString()->through(fn (MosquePayoutMethod $p) => self::row($p))),
            'state' => $state,
        ]);
    }

    /** Shows the full IBAN to the admin who asked, and logs it. */
    public function reveal(Request $request, MosquePayoutMethod $payout): JsonResponse
    {
        abort_unless($payout->type === 'bank' && $payout->iban, 404);
        Log::info('Admin revealed a mosque IBAN', ['admin_id' => $request->user()->id, 'payout_method_id' => $payout->id, 'mosque_id' => $payout->mosque_id]);

        return response()->json(['iban' => BankAccount::formatIban($payout->iban)])
            ->header('Cache-Control', 'no-store');
    }

    /**
     * Verifies the account exactly as the admin saw it: the page sends back
     * the version it showed, and a manager's change since then (a new IBAN,
     * another PayPal address) makes the verification fail instead.
     */
    public function verify(Request $request, MosquePayoutMethod $payout, FundraisingMail $mail): RedirectResponse
    {
        $seen = $request->input('version');
        $outcome = DB::transaction(function () use ($payout, $seen, $request): string {
            $locked = MosquePayoutMethod::query()->lockForUpdate()->find($payout->id);
            if (! $locked) {
                return 'changed';
            }
            if ($locked->isVerified()) {
                return 'already';
            }
            if (! ReviewVersion::matches(ReviewVersion::payout($locked), $seen)) {
                return 'changed';
            }
            $locked->forceFill(['verified_at' => now(), 'verified_by' => $request->user()->id])->save();
            $payout->setRawAttributes($locked->getAttributes(), true);

            return 'verified';
        });

        if ($outcome !== 'verified') {
            Inertia::flash('toast', $outcome === 'already'
                ? ['type' => 'info', 'message' => ui('fundraising.admin_payout_already')]
                : ['type' => 'error', 'message' => ui('fundraising.admin_payout_changed')]);

            return back(303);
        }
        Log::info('Admin verified a mosque payout method', ['admin_id' => $request->user()->id, 'payout_method_id' => $payout->id, 'mosque_id' => $payout->mosque_id]);

        $mosque = Mosque::query()->find($payout->mosque_id);
        if ($mosque) {
            $mail->toManagers($mosque, new PayoutVerified($payout));
        }
        Inertia::flash('toast', ['type' => 'success', 'message' => ui('fundraising.admin_payout_verified')]);

        return back(303);
    }

    public function unverify(Request $request, MosquePayoutMethod $payout): RedirectResponse
    {
        $payout->forceFill(['verified_at' => null, 'verified_by' => null])->save();
        Log::info('Admin withdrew a payout verification', ['admin_id' => $request->user()->id, 'payout_method_id' => $payout->id]);
        Inertia::flash('toast', ['type' => 'success', 'message' => ui('fundraising.admin_payout_unverified')]);

        return back(303);
    }

    /**
     * @param  Builder<MosquePayoutMethod>  $query
     * @return array<int, array<string, mixed>>
     */
    public static function rows(Builder $query): array
    {
        return $query->with('mosque:id,slug,name,city,verified_at')->get()
            ->map(fn (MosquePayoutMethod $p) => self::row($p))->values()->all();
    }

    /** @return array<string, mixed> */
    public static function row(MosquePayoutMethod $payout): array
    {
        $mosque = $payout->getRelationValue('mosque');
        $mosque = $mosque instanceof Mosque ? $mosque : null;

        return [
            ...PayoutPresenter::masked($payout),
            'version' => ReviewVersion::payout($payout),
            'verified_by' => $payout->getAttribute('verifier_name'),
            'mosque' => $mosque ? [
                'slug' => $mosque->slug,
                'name' => $mosque->name,
                'city' => $mosque->city,
                'verified' => $mosque->isVerified(),
            ] : null,
        ];
    }
}
