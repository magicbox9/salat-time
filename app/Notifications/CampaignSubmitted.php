<?php

namespace App\Notifications;

use App\Models\Campaign;
use App\Models\Mosque;
use Illuminate\Notifications\Messages\MailMessage;

/** Tells the platform admins a campaign is waiting for review. */
class CampaignSubmitted extends CampaignNotification
{
    public function __construct(public Campaign $campaign)
    {
        $this->afterCommit();
    }

    public function toMail(object $notifiable): MailMessage
    {
        $campaign = $this->campaign;

        return $this->message($this->subject('fundraising.mail_submitted_subject', ['campaign' => $campaign->title]), (string) data_get($notifiable, 'name'))
            ->line($this->textLine('fundraising.mail_submitted_line', [
                'mosque' => (string) Mosque::query()->whereKey($campaign->mosque_id)->value('name'),
                'campaign' => $campaign->title,
            ]))
            ->action(ui('fundraising.mail_submitted_action'), url('/admin/fundraising/campaigns/'.$campaign->slug));
    }

    /** @return array<string, mixed> */
    public function toArray(object $notifiable): array
    {
        return ['campaign_id' => $this->campaign->id];
    }
}
