<?php

namespace App\Services\Fundraising;

use App\Models\Donation;
use RuntimeException;

/**
 * Human references for donations ("ST-4F7K-9Q2M"): what a donor writes on a
 * bank transfer and quotes to the mosque. No 0/O or 1/I to misread, about
 * 10^12 combinations, and checked against the database before use.
 */
final class DonationReference
{
    private const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    public const PATTERN = '/^ST-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$/';

    public static function generate(): string
    {
        for ($attempt = 0; $attempt < 8; $attempt++) {
            $reference = 'ST-'.self::block().'-'.self::block();
            if (! Donation::query()->where('reference', $reference)->exists()) {
                return $reference;
            }
        }

        throw new RuntimeException('Could not find a free donation reference.');
    }

    private static function block(): string
    {
        $block = '';
        for ($i = 0; $i < 4; $i++) {
            $block .= self::ALPHABET[random_int(0, strlen(self::ALPHABET) - 1)];
        }

        return $block;
    }
}
