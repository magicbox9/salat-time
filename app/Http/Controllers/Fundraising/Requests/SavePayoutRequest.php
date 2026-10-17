<?php

namespace App\Http\Controllers\Fundraising\Requests;

use App\Http\Controllers\MosquePage\Support\PlainText;
use App\Models\Mosque;
use App\Models\MosquePayoutMethod;
use App\Services\Payments\BankAccount;
use Closure;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

/**
 * Where a mosque receives donations: its PayPal account (email or merchant
 * id) or its bank account (holder, IBAN checked with mod-97, BIC, bank).
 * Left empty, the IBAN of an existing bank account is kept.
 */
class SavePayoutRequest extends FormRequest
{
    public function authorize(): bool
    {
        $mosque = $this->route('mosque');

        return $mosque instanceof Mosque && (bool) $this->user()?->can('manage', $mosque);
    }

    protected function prepareForValidation(): void
    {
        $type = $this->route('type') ?? $this->input('type');
        $this->merge([
            'type' => $type,
            'paypal_email' => $this->filled('paypal_email') ? Str::lower(trim((string) $this->input('paypal_email'))) : null,
            'paypal_merchant_id' => $this->filled('paypal_merchant_id') ? strtoupper(trim((string) $this->input('paypal_merchant_id'))) : null,
            'iban' => $this->filled('iban') ? BankAccount::normalizeIban((string) $this->input('iban')) : null,
            'bic' => $this->filled('bic') ? BankAccount::normalizeBic((string) $this->input('bic')) : null,
        ]);
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        $type = $this->input('type');
        $rules = ['type' => ['required', 'string', Rule::in(MosquePayoutMethod::TYPES)]];

        if ($type === 'paypal') {
            return [
                ...$rules,
                'paypal_email' => ['nullable', 'required_without:paypal_merchant_id', 'string', 'email:rfc', 'max:200'],
                'paypal_merchant_id' => ['nullable', 'string', 'regex:/^[A-Z0-9]{13}$/'],
            ];
        }

        if ($type === 'bank') {
            return [
                ...$rules,
                'account_holder' => ['required', 'string', PlainText::RULE, 'min:2', 'max:200'],
                'iban' => [$this->hasStoredIban() ? 'nullable' : 'required', 'string', 'max:34', function (string $attribute, mixed $value, Closure $fail) {
                    if (is_string($value) && ! BankAccount::isValidIban($value)) {
                        $fail(ui('fundraising.v_iban'));
                    }
                }],
                'bic' => ['nullable', 'string', function (string $attribute, mixed $value, Closure $fail) {
                    if (is_string($value) && ! BankAccount::isValidBic($value)) {
                        $fail(ui('fundraising.v_bic'));
                    }
                }],
                'bank_name' => ['nullable', 'string', PlainText::RULE, 'max:120'],
            ];
        }

        return $rules;
    }

    /** @return array<string, string> */
    public function messages(): array
    {
        return [
            'paypal_email.required_without' => ui('fundraising.v_paypal_required'),
            'paypal_merchant_id.regex' => ui('fundraising.v_merchant_id'),
        ];
    }

    /** @return array<string, string> */
    public function attributes(): array
    {
        return [
            'paypal_email' => ui('fundraising.field_paypal_email'),
            'paypal_merchant_id' => ui('fundraising.field_merchant_id'),
            'account_holder' => ui('fundraising.field_account_holder'),
            'iban' => 'IBAN',
            'bic' => 'BIC',
            'bank_name' => ui('fundraising.field_bank_name'),
        ];
    }

    private function hasStoredIban(): bool
    {
        $mosque = $this->route('mosque');

        return $mosque instanceof Mosque && MosquePayoutMethod::query()
            ->where('mosque_id', $mosque->id)
            ->where('type', 'bank')
            ->whereNotNull('iban')
            ->exists();
    }
}
