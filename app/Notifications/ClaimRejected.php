<?php

namespace App\Notifications;

use Illuminate\Notifications\Messages\MailMessage;

/** Tells the claimant their request was not approved, and why. */
class ClaimRejected extends ClaimNotification
{
    public function toMail(object $notifiable): MailMessage
    {
        $mosque = $this->mosqueName();
        $mail = $this->message($notifiable, $this->subject('claims.mail_rejected_subject', ['mosque' => $mosque]))
            ->line($this->textLine('claims.mail_rejected_line', ['mosque' => $mosque]));

        return $this->noteLines($mail, 'claims.mail_reason', $this->claim->review_note)
            ->line(ui('claims.mail_rejected_next'))
            ->action(ui('claims.mail_rejected_action'), route('claims.mine'));
    }
}
