<?php

namespace App\Notifications;

use App\Models\Mosque;
use App\Models\MosquePayoutMethod;
use Illuminate\Notifications\Messages\MailMessage;

/** Tells a mosque's managers an admin verified the account donations go to. */
class PayoutVerified extends CampaignNotification
{
    public function __construct(public MosquePayoutMethod $payout)
    {
        $this->afterCommit();
    }

    public function toMail(object $notifiable): MailMessage
    {
        $payout = $this->payout;
        $mosque = Mosque::query()->find($payout->mosque_id, ['id', 'slug', 'name']);

        return $this->message($this->subject('fundraising.mail_payout_subject'), (string) data_get($notifiable, 'name'))
            ->line($this->textLine('fundraising.mail_payout_line', [
                'method' => ui('fundraising.method_'.$payout->type),
                'mosque' => (string) $mosque?->name,
            ]))
            ->action(ui('fundraising.mail_payout_action'), url('/manage/'.$mosque?->slug.'/campaigns'));
    }

    /** @return array<string, mixed> */
    public function toArray(object $notifiable): array
    {
        return ['payout_method_id' => $this->payout->id];
    }
}
