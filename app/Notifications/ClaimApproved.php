<?php

namespace App\Notifications;

use Illuminate\Notifications\Messages\MailMessage;

/** Tells the claimant they now manage the mosque's page. */
class ClaimApproved extends ClaimNotification
{
    public function toMail(object $notifiable): MailMessage
    {
        $mosque = $this->mosqueName();
        $mail = $this->message($notifiable, $this->subject('claims.mail_approved_subject', ['mosque' => $mosque]))
            ->line($this->textLine('claims.mail_approved_line', ['mosque' => $mosque]));

        return $this->noteLines($mail, 'claims.mail_note', $this->claim->review_note)
            ->action(ui('claims.mail_approved_action'), url('/manage'))
            ->line(ui('claims.mail_approved_next'));
    }
}
