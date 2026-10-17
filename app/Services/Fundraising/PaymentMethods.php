<?php

namespace App\Services\Fundraising;

use App\Models\Campaign;
use App\Models\Mosque;
use App\Models\MosquePayoutMethod;
use App\Services\Payments\PayPalClient;

/**
 * Which ways of giving a campaign offers right now. A method is offered only
 * when the campaign allows it, the mosque is verified, the mosque's own
 * account for it is verified by an admin, and (for PayPal) the platform's
 * PayPal app is configured.
 */
class PaymentMethods
{
    public function __construct(private readonly PayPalClient $paypal) {}

    /**
     * The mosque's verified payout methods, keyed by type.
     *
     * @return array{paypal: MosquePayoutMethod|null, bank: MosquePayoutMethod|null}
     */
    public function verifiedPayouts(Mosque $mosque): array
    {
        /** @var iterable<MosquePayoutMethod> $methods */
        $methods = $mosque->relationLoaded('payoutMethods')
            ? $mosque->getRelation('payoutMethods')
            : MosquePayoutMethod::query()->where('mosque_id', $mosque->id)->get();

        $verified = ['paypal' => null, 'bank' => null];
        foreach ($methods as $method) {
            if ($method->isVerified() && array_key_exists($method->type, $verified)) {
                $verified[$method->type] = $method;
            }
        }

        return $verified;
    }

    /**
     * Methods a donor may use for this campaign now.
     *
     * @return array{paypal: bool, bank: bool}
     */
    public function available(Campaign $campaign): array
    {
        $mosque = CampaignPresenter::mosqueOf($campaign);
        if (! $mosque || ! $campaign->isOpen() || ! $mosque->isVerified() || ModelDate::of($campaign, 'starts_at')?->isFuture()) {
            return ['paypal' => false, 'bank' => false];
        }
        $payouts = $this->verifiedPayouts($mosque);

        return [
            'paypal' => $campaign->allow_paypal && $payouts['paypal'] !== null && $this->paypal->isConfigured(),
            'bank' => $campaign->allow_bank && $payouts['bank'] !== null,
        ];
    }

    /**
     * Methods the mosque could allow on a campaign: those with a verified
     * account. Whether the platform's PayPal app is configured is checked
     * when a donor gives (available()), not here.
     *
     * @return array{paypal: bool, bank: bool}
     */
    public function allowable(Mosque $mosque): array
    {
        $payouts = $this->verifiedPayouts($mosque);

        return ['paypal' => $payouts['paypal'] !== null, 'bank' => $payouts['bank'] !== null];
    }

    /**
     * The payee of a PayPal order: the merchant id when known, else the email.
     *
     * @return array{email_address?: string, merchant_id?: string}
     */
    public static function payee(MosquePayoutMethod $paypal): array
    {
        return $paypal->paypal_merchant_id
            ? ['merchant_id' => (string) $paypal->paypal_merchant_id]
            : ['email_address' => (string) $paypal->paypal_email];
    }

    /** What the JavaScript SDK's merchant-id parameter needs for this payee. */
    public static function sdkMerchant(MosquePayoutMethod $paypal): string
    {
        return (string) ($paypal->paypal_merchant_id ?: $paypal->paypal_email);
    }
}
