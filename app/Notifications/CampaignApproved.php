<?php

namespace App\Notifications;

use App\Models\Campaign;
use Illuminate\Notifications\Messages\MailMessage;

/** Tells a mosque's managers their campaign is now public. */
class CampaignApproved extends CampaignNotification
{
    public function __construct(public Campaign $campaign)
    {
        $this->afterCommit();
    }

    public function toMail(object $notifiable): MailMessage
    {
        $campaign = $this->campaign;
        $mail = $this->message($this->subject('fundraising.mail_approved_subject', ['campaign' => $campaign->title]), (string) data_get($notifiable, 'name'))
            ->line($this->textLine('fundraising.mail_approved_line', ['campaign' => $campaign->title]));

        return $this->noteLines($mail, 'fundraising.mail_note', $campaign->review_note)
            ->action(ui('fundraising.mail_view_campaign'), url('/campaigns/'.$campaign->slug))
            ->line(ui('fundraising.mail_approved_next'));
    }

    /** @return array<string, mixed> */
    public function toArray(object $notifiable): array
    {
        return ['campaign_id' => $this->campaign->id, 'status' => 'active'];
    }
}
