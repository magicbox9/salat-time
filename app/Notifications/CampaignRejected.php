<?php

namespace App\Notifications;

use App\Models\Campaign;
use App\Models\Mosque;
use Illuminate\Notifications\Messages\MailMessage;

/** Tells a mosque's managers their campaign needs changes, with the reason. */
class CampaignRejected extends CampaignNotification
{
    public function __construct(public Campaign $campaign)
    {
        $this->afterCommit();
    }

    public function toMail(object $notifiable): MailMessage
    {
        $campaign = $this->campaign;
        $mosqueSlug = (string) Mosque::query()->whereKey($campaign->mosque_id)->value('slug');
        $mail = $this->message($this->subject('fundraising.mail_rejected_subject', ['campaign' => $campaign->title]), (string) data_get($notifiable, 'name'))
            ->line($this->textLine('fundraising.mail_rejected_line', ['campaign' => $campaign->title]));

        return $this->noteLines($mail, 'fundraising.mail_note', $campaign->review_note)
            ->action(ui('fundraising.mail_rejected_action'), url('/manage/'.$mosqueSlug.'/campaigns/'.$campaign->slug.'/edit'))
            ->line(ui('fundraising.mail_rejected_next'));
    }

    /** @return array<string, mixed> */
    public function toArray(object $notifiable): array
    {
        return ['campaign_id' => $this->campaign->id, 'status' => 'rejected'];
    }
}
