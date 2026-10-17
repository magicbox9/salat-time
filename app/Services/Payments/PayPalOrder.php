<?php

namespace App\Services\Payments;

/**
 * The parts of a PayPal Orders v2 order we check before counting a donation:
 * the order and capture status, the captured amount and currency, the payee
 * and our reference (custom_id).
 */
final class PayPalOrder
{
    public function __construct(
        public readonly string $id,
        public readonly string $status,
        public readonly ?string $captureId,
        public readonly ?string $captureStatus,
        public readonly ?int $amount,
        public readonly ?string $currency,
        public readonly ?string $payeeEmail,
        public readonly ?string $payeeMerchantId,
        public readonly ?string $customId,
    ) {}

    /** @param  array<string, mixed>  $order  An order as PayPal returns it. */
    public static function fromArray(array $order): self
    {
        $unit = (array) data_get($order, 'purchase_units.0', []);
        $capture = (array) data_get($unit, 'payments.captures.0', []);
        $amount = $capture['amount'] ?? $unit['amount'] ?? [];

        return new self(
            id: (string) ($order['id'] ?? ''),
            status: (string) ($order['status'] ?? ''),
            captureId: self::string($capture['id'] ?? null),
            captureStatus: self::string($capture['status'] ?? null),
            amount: self::cents(data_get($amount, 'value')),
            currency: self::string(data_get($amount, 'currency_code')),
            payeeEmail: self::string(data_get($unit, 'payee.email_address')),
            payeeMerchantId: self::string(data_get($unit, 'payee.merchant_id')),
            customId: self::string($capture['custom_id'] ?? $unit['custom_id'] ?? null),
        );
    }

    /** The money is with the mosque. */
    public function isCompleted(): bool
    {
        return $this->status === 'COMPLETED' && $this->captureStatus === 'COMPLETED';
    }

    /**
     * "25.00" → 2500. Null for anything that is not a plain decimal amount
     * with at most two decimals (EUR).
     */
    public static function cents(mixed $value): ?int
    {
        if (! is_string($value) && ! is_int($value)) {
            return null;
        }
        $value = (string) $value;
        if (! preg_match('/^(\d{1,12})(?:\.(\d{1,2}))?$/', $value, $m)) {
            return null;
        }

        return (int) $m[1] * 100 + (int) str_pad($m[2] ?? '0', 2, '0');
    }

    /** 2500 → "25.00" */
    public static function value(int $cents): string
    {
        return intdiv($cents, 100).'.'.str_pad((string) ($cents % 100), 2, '0', STR_PAD_LEFT);
    }

    private static function string(mixed $value): ?string
    {
        return is_string($value) && $value !== '' ? $value : null;
    }
}
