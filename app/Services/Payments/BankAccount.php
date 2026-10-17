<?php

namespace App\Services\Payments;

/**
 * IBAN and BIC checks for a mosque's bank account: the country's length, the
 * ISO 13616 mod-97 checksum, and the SWIFT BIC format.
 */
final class BankAccount
{
    /** IBAN length by country (SEPA and the countries mosques most often bank in). */
    private const LENGTHS = [
        'AD' => 24, 'AE' => 23, 'AL' => 28, 'AT' => 20, 'AZ' => 28, 'BA' => 20, 'BE' => 16, 'BG' => 22,
        'BH' => 22, 'CH' => 21, 'CY' => 28, 'CZ' => 24, 'DE' => 22, 'DK' => 18, 'DZ' => 26, 'EE' => 20,
        'EG' => 29, 'ES' => 24, 'FI' => 18, 'FO' => 18, 'FR' => 27, 'GB' => 22, 'GE' => 22, 'GI' => 23,
        'GL' => 18, 'GR' => 27, 'HR' => 21, 'HU' => 28, 'IE' => 22, 'IL' => 23, 'IQ' => 23, 'IS' => 26,
        'IT' => 27, 'JO' => 30, 'KW' => 30, 'KZ' => 20, 'LB' => 28, 'LI' => 21, 'LT' => 20, 'LU' => 20,
        'LV' => 21, 'MA' => 28, 'MC' => 27, 'MD' => 24, 'ME' => 22, 'MK' => 19, 'MR' => 27, 'MT' => 31,
        'NL' => 18, 'NO' => 15, 'PK' => 24, 'PL' => 28, 'PS' => 29, 'PT' => 25, 'QA' => 29, 'RO' => 24,
        'RS' => 22, 'SA' => 24, 'SE' => 24, 'SI' => 19, 'SK' => 24, 'SM' => 27, 'SN' => 28, 'TN' => 24,
        'TR' => 26, 'UA' => 29, 'VA' => 22, 'XK' => 20,
    ];

    /** "fr76 3000 6000…" → "FR7630006000…" */
    public static function normalizeIban(?string $iban): string
    {
        return strtoupper((string) preg_replace('/[\s\-.]+/', '', (string) $iban));
    }

    public static function isValidIban(?string $iban): bool
    {
        $iban = self::normalizeIban($iban);
        if (! preg_match('/^([A-Z]{2})(\d{2})([A-Z0-9]{11,30})$/', $iban, $m)) {
            return false;
        }
        $length = self::LENGTHS[$m[1]] ?? null;
        if ($length !== null && strlen($iban) !== $length) {
            return false;
        }

        return self::mod97(substr($iban, 4).substr($iban, 0, 4)) === 1;
    }

    /** "FR7630006000011234567890189" → "FR76 3000 6000 0112 3456 7890 189" */
    public static function formatIban(?string $iban): string
    {
        return trim(chunk_split(self::normalizeIban($iban), 4, ' '));
    }

    public static function normalizeBic(?string $bic): string
    {
        return strtoupper((string) preg_replace('/\s+/', '', (string) $bic));
    }

    /** 8 or 11 characters: bank (4 letters), country (2 letters), location (2), branch (3, optional). */
    public static function isValidBic(?string $bic): bool
    {
        return (bool) preg_match('/^[A-Z]{4}[A-Z]{2}[A-Z0-9]{2}([A-Z0-9]{3})?$/', self::normalizeBic($bic));
    }

    /** Remainder of a long alphanumeric number by 97 (letters count as 10–35). */
    private static function mod97(string $value): int
    {
        $digits = '';
        foreach (str_split($value) as $char) {
            $digits .= ctype_alpha($char) ? (string) (ord($char) - 55) : $char;
        }

        $remainder = 0;
        foreach (str_split($digits, 7) as $chunk) {
            $remainder = ((int) ($remainder.$chunk)) % 97;
        }

        return $remainder;
    }
}
