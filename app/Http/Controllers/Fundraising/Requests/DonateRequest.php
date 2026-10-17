<?php

namespace App\Http\Controllers\Fundraising\Requests;

use App\Http\Controllers\MosquePage\Support\PlainText;
use Illuminate\Foundation\Http\FormRequest;

/**
 * A donor's gift: an amount in cents (1 € to 100,000 €), who they are, and
 * whether their name may appear on the campaign. Anyone may give, signed in
 * or not; the payment method is chosen by the route.
 */
class DonateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        $user = $this->user();
        $this->merge([
            'donor_name' => $this->input('donor_name') ?: $user?->name,
            'donor_email' => $this->input('donor_email') ?: $user?->email,
        ]);
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'amount' => ['required', 'integer', 'min:'.config('fundraising.min_amount'), 'max:'.config('fundraising.max_amount')],
            'donor_name' => ['required', 'string', PlainText::RULE, 'min:2', 'max:120'],
            'donor_email' => ['required', 'string', 'email:rfc', 'max:200'],
            'anonymous' => ['boolean'],
            'message' => ['nullable', 'string', PlainText::RULE, 'max:500'],
        ];
    }

    /** @return array<string, string> */
    public function messages(): array
    {
        $range = [
            'min' => number_format(config('fundraising.min_amount') / 100, 0, ',', ' ').' €',
            'max' => number_format(config('fundraising.max_amount') / 100, 0, ',', ' ').' €',
        ];

        return [
            'amount.required' => ui('fundraising.v_amount_range', $range),
            'amount.integer' => ui('fundraising.v_amount_range', $range),
            'amount.min' => ui('fundraising.v_amount_range', $range),
            'amount.max' => ui('fundraising.v_amount_range', $range),
        ];
    }

    /** @return array<string, string> */
    public function attributes(): array
    {
        return [
            'donor_name' => ui('fundraising.field_name'),
            'donor_email' => ui('fundraising.field_email'),
            'message' => ui('fundraising.field_message'),
        ];
    }
}
