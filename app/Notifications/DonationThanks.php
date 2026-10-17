<?php

namespace App\Notifications;

use App\Models\Campaign;
use App\Models\Donation;
use App\Models\Mosque;
use Illuminate\Notifications\Messages\MailMessage;

/**
 * Thanks the donor once the mosque has the money (PayPal captured, or the
 * bank transfer confirmed by the mosque), with the amount and reference.
 */
class DonationThanks extends CampaignNotification
{
    public function __construct(public Donation $donation)
    {
        $this->afterCommit();
    }

    public function toMail(object $notifiable): MailMessage
    {
        $donation = $this->donation;
        $record = Campaign::withTrashed()->find($donation->campaign_id, ['id', 'slug', 'title']);
        $campaign = (string) $record?->title;
        $mosque = (string) Mosque::query()->whereKey($donation->mosque_id)->value('name');

        return $this->message($this->subject('fundraising.mail_thanks_subject', ['campaign' => $campaign]), $donation->donor_name)
            ->line($this->textLine('fundraising.mail_thanks_line', [
                'amount' => $this->money($donation->amount, $donation->currency),
                'mosque' => $mosque,
                'campaign' => $campaign,
            ]))
            ->line($this->textLine('fundraising.mail_reference', ['reference' => $donation->reference]))
            ->line(ui('fundraising.mail_direct'))
            ->line(ui('fundraising.mail_tax_receipt'))
            ->action(ui('fundraising.mail_view_campaign'), url('/campaigns/'.$record?->slug))
            ->line(ui('fundraising.mail_dua'));
    }

    /** @return array<string, mixed> */
    public function toArray(object $notifiable): array
    {
        return ['donation_id' => $this->donation->id];
    }
}
