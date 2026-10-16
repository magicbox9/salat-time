<?php

namespace App\Notifications;

use App\Models\User;
use Illuminate\Notifications\Messages\MailMessage;

/** Tells a platform admin that a new request to manage a mosque is waiting. */
class ClaimSubmitted extends ClaimNotification
{
    public function toMail(object $notifiable): MailMessage
    {
        $mosque = $this->mosqueName();

        // The claimant's name and role are typed by them: textLine() keeps them inert.
        return $this->message($notifiable, $this->subject('claims.mail_submitted_subject', ['mosque' => $mosque]))
            ->line($this->textLine('claims.mail_submitted_line', [
                'claimant' => (string) User::query()->whereKey($this->claim->user_id)->value('name'),
                'mosque' => $mosque,
            ]))
            ->line($this->textLine('claims.mail_submitted_role', ['role' => $this->claim->role_at_mosque]))
            ->action(ui('claims.mail_submitted_action'), route('admin.claims.show', $this->claim));
    }
}
