<?php

namespace App\Services\Fundraising;

use App\Models\MosquePayoutMethod;
use App\Services\Payments\BankAccount;

/**
 * A mosque's payout method for the pages. The IBAN is always masked here;
 * only the admin "reveal" action and the donor's transfer instructions show
 * it in full.
 */
class PayoutPresenter
{
    /** @return array<string, mixed> */
    public static function masked(MosquePayoutMethod $payout): array
    {
        return [
            'id' => $payout->id,
            'type' => $payout->type,
            'paypal_email' => $payout->paypal_email,
            'paypal_merchant_id' => $payout->paypal_merchant_id,
            'account_holder' => $payout->account_holder,
            'iban_masked' => $payout->maskedIban(),
            'bic' => $payout->bic,
            'bank_name' => $payout->bank_name,
            'verified' => $payout->isVerified(),
            'verified_at' => ModelDate::iso($payout, 'verified_at'),
            'updated_at' => ModelDate::iso($payout, 'updated_at'),
        ];
    }

    /**
     * What a donor needs for a transfer.
     *
     * @return array<string, string|null>
     */
    public static function transfer(MosquePayoutMethod $bank): array
    {
        return [
            'account_holder' => $bank->account_holder,
            'iban' => BankAccount::formatIban($bank->iban),
            'bic' => $bank->bic,
            'bank_name' => $bank->bank_name,
        ];
    }
}
