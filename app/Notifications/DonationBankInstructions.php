<?php

namespace App\Notifications;

use App\Http\Controllers\Fundraising\DonationReceiptController;
use App\Models\Campaign;
use App\Models\Donation;
use App\Models\Mosque;
use App\Models\MosquePayoutMethod;
use App\Services\Payments\BankAccount;
use Illuminate\Notifications\Messages\MailMessage;

/**
 * Sent when a donor chooses a bank transfer: the mosque's own account, the
 * exact amount and the reference to write on the transfer.
 */
class DonationBankInstructions extends CampaignNotification
{
    public function __construct(public Donation $donation)
    {
        $this->afterCommit();
    }

    public function toMail(object $notifiable): MailMessage
    {
        $donation = $this->donation;
        $campaign = (string) Campaign::withTrashed()->whereKey($donation->campaign_id)->value('title');
        $bank = MosquePayoutMethod::query()
            ->where('mosque_id', $donation->mosque_id)
            ->where('type', 'bank')
            ->whereNotNull('verified_at')
            ->first();

        $mail = $this->message($this->subject('fundraising.mail_bank_subject', ['campaign' => $campaign]), $donation->donor_name)
            ->line($this->textLine('fundraising.mail_bank_line', [
                'mosque' => (string) Mosque::query()->whereKey($donation->mosque_id)->value('name'),
                'campaign' => $campaign,
            ]));

        if ($bank) {
            $mail->line($this->textLine('fundraising.mail_bank_holder', ['holder' => $bank->account_holder]))
                ->line($this->textLine('fundraising.mail_bank_iban', ['iban' => BankAccount::formatIban($bank->iban)]));
            if ($bank->bic) {
                $mail->line($this->textLine('fundraising.mail_bank_bic', ['bic' => $bank->bic]));
            }
            if ($bank->bank_name) {
                $mail->line($this->textLine('fundraising.mail_bank_name', ['bank' => $bank->bank_name]));
            }
        }

        return $mail
            ->line($this->textLine('fundraising.mail_bank_amount', ['amount' => $this->money($donation->amount, $donation->currency)]))
            ->line($this->textLine('fundraising.mail_bank_reference', ['reference' => $donation->reference]))
            ->line(ui('fundraising.mail_bank_sepa'))
            ->action(ui('fundraising.mail_bank_action'), DonationReceiptController::link($donation->reference, absolute: true))
            ->line(ui('fundraising.mail_bank_confirm'))
            ->line(ui('fundraising.mail_tax_receipt'));
    }

    /** @return array<string, mixed> */
    public function toArray(object $notifiable): array
    {
        return ['donation_id' => $this->donation->id];
    }
}
