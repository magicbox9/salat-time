<?php

namespace App\Http\Controllers\Fundraising\Manage;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Fundraising\Requests\SavePayoutRequest;
use App\Models\Mosque;
use App\Models\MosquePayoutMethod;
use App\Services\Fundraising\PayoutPresenter;
use App\Services\Payments\PayPalClient;
use App\Support\MosquePresenter;
use Illuminate\Http\RedirectResponse;
use Inertia\Inertia;
use Inertia\Response;

/**
 * /manage/{mosque}/payouts — the mosque's own accounts donations go to. Any
 * change to an account sends it back to the admins for verification.
 */
class PayoutMethodController extends Controller
{
    private const FIELDS = ['paypal_email', 'paypal_merchant_id', 'account_holder', 'iban', 'bic', 'bank_name'];

    public function index(Mosque $mosque, PayPalClient $paypal): Response
    {
        $payouts = MosquePayoutMethod::query()->where('mosque_id', $mosque->id)->get()->keyBy('type');
        $paypalPayout = $payouts->get('paypal');
        $bankPayout = $payouts->get('bank');

        return Inertia::render('fundraising/payouts', [
            'mosque' => MosquePresenter::summary($mosque),
            'paypal' => $paypalPayout ? PayoutPresenter::masked($paypalPayout) : null,
            'bank' => $bankPayout ? PayoutPresenter::masked($bankPayout) : null,
            'paypalEnabled' => $paypal->isConfigured(),
            'mosqueVerified' => $mosque->isVerified(),
        ]);
    }

    public function store(SavePayoutRequest $request, Mosque $mosque): RedirectResponse
    {
        return $this->save($request, $mosque, (string) $request->validated('type'));
    }

    public function update(SavePayoutRequest $request, Mosque $mosque, string $type): RedirectResponse
    {
        return $this->save($request, $mosque, $type);
    }

    public function destroy(Mosque $mosque, string $type): RedirectResponse
    {
        MosquePayoutMethod::query()->where('mosque_id', $mosque->id)->where('type', $type)->delete();
        Inertia::flash('toast', ['type' => 'success', 'message' => ui('fundraising.payout_deleted')]);

        return to_route('manage.payouts.index', $mosque);
    }

    private function save(SavePayoutRequest $request, Mosque $mosque, string $type): RedirectResponse
    {
        $data = $request->validated();
        $payout = MosquePayoutMethod::query()->firstOrNew(['mosque_id' => $mosque->id, 'type' => $type]);

        if ($type === 'paypal') {
            $payout->fill([
                'paypal_email' => $data['paypal_email'] ?? null,
                'paypal_merchant_id' => $data['paypal_merchant_id'] ?? null,
                'account_holder' => null, 'iban' => null, 'bic' => null, 'bank_name' => null,
            ]);
        } else {
            $payout->fill([
                'paypal_email' => null,
                'paypal_merchant_id' => null,
                'account_holder' => trim((string) $data['account_holder']),
                'bic' => $data['bic'] ?? null,
                'bank_name' => isset($data['bank_name']) ? trim((string) $data['bank_name']) : null,
            ]);
            if (! empty($data['iban'])) {
                $payout->iban = $data['iban'];
            }
        }

        // A changed account must be verified again before it receives anything.
        $changed = ! $payout->exists || $payout->isDirty(self::FIELDS);
        if ($changed) {
            $payout->forceFill(['verified_at' => null, 'verified_by' => null]);
        }
        $payout->save();

        Inertia::flash('toast', [
            'type' => 'success',
            'message' => ui($changed ? 'fundraising.payout_saved_review' : 'fundraising.payout_unchanged'),
        ]);

        return to_route('manage.payouts.index', $mosque);
    }
}
