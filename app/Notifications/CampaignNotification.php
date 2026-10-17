<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;
use Illuminate\Support\HtmlString;
use Illuminate\Support\Str;

/**
 * Base of the fundraising emails (donors, mosque managers, admins). They are
 * queued, sent once the database transaction is committed, and written with
 * ui() in the recipient's language (the sender sets ->locale()).
 *
 * Text typed by people (campaign titles, mosque and donor names, review
 * notes) goes through textLine() so it reads exactly as typed and can never
 * become a link, an image or a heading in the Markdown body.
 */
abstract class CampaignNotification extends Notification implements ShouldQueue
{
    use Queueable;

    /** The record may be deleted before the queue runs: drop the email then. */
    public bool $deleteWhenMissingModels = true;

    private const INERT = [
        '&' => '&amp;', '<' => '&lt;', '>' => '&gt;', '"' => '&quot;', "'" => '&#39;',
        '\\' => '&#92;', '`' => '&#96;', '*' => '&#42;', '_' => '&#95;', '{' => '&#123;', '}' => '&#125;',
        '[' => '&#91;', ']' => '&#93;', '(' => '&#40;', ')' => '&#41;', '#' => '&#35;', '+' => '&#43;',
        '-' => '&#45;', '.' => '&#46;', '!' => '&#33;', '|' => '&#124;', '~' => '&#126;', '=' => '&#61;',
    ];

    /** @return array<int, string> */
    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    /** A message with the shared greeting and signature. */
    protected function message(string $subject, ?string $name): MailMessage
    {
        $greeting = trim((string) $name) !== ''
            ? $this->textLine('fundraising.mail_greeting', ['name' => $name])
            : new HtmlString(e(ui('fundraising.mail_greeting_plain')));

        return (new MailMessage)
            ->subject($subject)
            ->greeting($greeting)
            ->salutation(ui('fundraising.mail_salutation'));
    }

    /**
     * A translated subject line (not Markdown), kept on one line.
     *
     * @param  array<string, string|null>  $replace
     */
    protected function subject(string $key, array $replace = []): string
    {
        return ui($key, array_map(fn (?string $value): string => Str::squish((string) $value), $replace));
    }

    /**
     * A translated body line whose {placeholders} hold text typed by people.
     *
     * @param  array<string, string|null>  $replace
     */
    protected function textLine(string $key, array $replace = []): HtmlString
    {
        $values = [];
        foreach ($replace as $name => $value) {
            $values['{'.$name.'}'] = self::inert((string) $value);
        }

        return new HtmlString(strtr(e(ui($key)), $values));
    }

    /** Adds a note written by our team, paragraph by paragraph, after a translated label. */
    protected function noteLines(MailMessage $mail, string $key, ?string $note): MailMessage
    {
        $paragraphs = array_values(array_filter(
            preg_split('/\R+/u', trim((string) $note)) ?: [],
            fn (string $paragraph): bool => trim($paragraph) !== '',
        ));
        if ($paragraphs === []) {
            return $mail;
        }

        $mail->line($this->textLine($key, ['note' => array_shift($paragraphs)]));
        foreach ($paragraphs as $paragraph) {
            $mail->line(new HtmlString(self::inert($paragraph)));
        }

        return $mail;
    }

    /** "1 234,50 €" in the mail's language. */
    protected function money(int $cents, string $currency): string
    {
        $locale = app()->getLocale() === 'ar' ? 'ar@numbers=latn' : app()->getLocale();
        if (class_exists(\NumberFormatter::class)) {
            $formatted = (new \NumberFormatter($locale, \NumberFormatter::CURRENCY))->formatCurrency($cents / 100, $currency);
            if ($formatted !== false) {
                return $formatted;
            }
        }

        return number_format($cents / 100, 2, ',', ' ').' '.$currency;
    }

    /** One line of plain text, safe in the Markdown body. */
    protected static function inert(string $value): string
    {
        return strtr(Str::squish($value), self::INERT);
    }
}
