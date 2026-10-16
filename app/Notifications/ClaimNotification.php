<?php

namespace App\Notifications;

use App\Models\Mosque;
use App\Models\MosqueClaim;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;
use Illuminate\Support\HtmlString;
use Illuminate\Support\Str;

/**
 * Base for the claim emails. They are queued (sent once the database
 * transaction is committed) and written with ui() in the recipient's
 * language: the sender sets ->locale(), which Laravel applies while the
 * message is built.
 *
 * The body is Markdown. Text typed by people (names, the role at the mosque,
 * mosque names, review notes) goes through textLine() so it reads exactly as
 * typed and can never turn into a link, an image or a heading.
 */
abstract class ClaimNotification extends Notification implements ShouldQueue
{
    use Queueable;

    /** The claim (or its user) may be deleted before the queue runs: drop the email then. */
    public bool $deleteWhenMissingModels = true;

    /**
     * HTML and Markdown characters written as entities: the Markdown parser
     * treats them as plain characters, the plain-text part decodes them back.
     */
    private const INERT = [
        '&' => '&amp;', '<' => '&lt;', '>' => '&gt;', '"' => '&quot;', "'" => '&#39;',
        '\\' => '&#92;', '`' => '&#96;', '*' => '&#42;', '_' => '&#95;', '{' => '&#123;', '}' => '&#125;',
        '[' => '&#91;', ']' => '&#93;', '(' => '&#40;', ')' => '&#41;', '#' => '&#35;', '+' => '&#43;',
        '-' => '&#45;', '.' => '&#46;', '!' => '&#33;', '|' => '&#124;', '~' => '&#126;', '=' => '&#61;',
    ];

    public function __construct(public MosqueClaim $claim)
    {
        $this->afterCommit();
    }

    /** @return array<int, string> */
    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    /** A message with the shared greeting and signature. */
    protected function message(object $notifiable, string $subject): MailMessage
    {
        return (new MailMessage)
            ->subject($subject)
            ->greeting($this->textLine('claims.mail_greeting', ['name' => (string) data_get($notifiable, 'name')]))
            ->salutation(ui('claims.mail_salutation'));
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

    /**
     * Adds a note written by our team: its first paragraph in the translated
     * line ("Reason: …"), the following paragraphs as lines of their own.
     */
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

    protected function mosqueName(): string
    {
        return (string) Mosque::query()->whereKey($this->claim->mosque_id)->value('name');
    }

    /** @return array<string, mixed> */
    public function toArray(object $notifiable): array
    {
        return ['claim_id' => $this->claim->id, 'status' => $this->claim->status];
    }

    /** One line of plain text, safe in the Markdown body. */
    private static function inert(string $value): string
    {
        return strtr(Str::squish($value), self::INERT);
    }
}
