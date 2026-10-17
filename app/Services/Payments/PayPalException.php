<?php

namespace App\Services\Payments;

use RuntimeException;

/**
 * PayPal could not be reached or refused a request. The message holds the
 * HTTP status and PayPal's error name only, never credentials or payloads.
 */
class PayPalException extends RuntimeException
{
    public function __construct(string $message, public readonly ?int $status = null, public readonly ?string $issue = null)
    {
        parent::__construct($message);
    }

    /** PayPal says the order was already captured (a repeated capture). */
    public function alreadyCaptured(): bool
    {
        return $this->issue === 'ORDER_ALREADY_CAPTURED';
    }
}
