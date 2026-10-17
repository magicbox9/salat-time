<?php

namespace App\Http\Controllers\Fundraising;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Fundraising\Requests\DonateRequest;
use App\Models\Campaign;
use App\Services\Fundraising\DonationIntake;
use App\Services\Fundraising\FundraisingMail;
use App\Services\Fundraising\PaymentMethods;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Validation\ValidationException;

/**
 * A donor announces a bank transfer: a pending donation with its own
 * reference, shown as "pledged" until the mosque confirms the money arrived.
 * The donor is sent to the transfer instructions (and gets them by email).
 */
class BankDonationController extends Controller
{
    private const PLEDGES_PER_EMAIL_HOUR = 5;

    public function store(DonateRequest $request, Campaign $campaign, PaymentMethods $methods, DonationIntake $intake, FundraisingMail $mail): RedirectResponse
    {
        $campaign->loadMissing('mosque.payoutMethods');
        if (! $methods->available($campaign)['bank']) {
            throw ValidationException::withMessages(['method' => ui('fundraising.method_unavailable')]);
        }

        /** @var array{amount: int, donor_name: string, donor_email: string, anonymous?: bool, message?: string|null} $data */
        $data = $request->validated();

        // Each pledge emails its instructions: a few per address and hour, so the
        // form cannot be used to flood someone else's inbox.
        $key = 'bank-pledge:'.hash('sha256', strtolower(trim($data['donor_email'])));
        if (RateLimiter::tooManyAttempts($key, self::PLEDGES_PER_EMAIL_HOUR)) {
            throw ValidationException::withMessages(['donor_email' => ui('fundraising.v_too_many_pledges')]);
        }
        RateLimiter::hit($key, 3600);

        $donation = $intake->create($campaign, 'bank', $data, $request->user());
        $mail->bankInstructions($donation);

        return redirect()->to(DonationReceiptController::link($donation->reference));
    }
}
