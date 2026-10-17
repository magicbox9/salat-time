<?php

namespace App\Http\Controllers\Fundraising\Requests;

use App\Http\Controllers\MosquePage\Support\PlainText;
use App\Models\Campaign;
use App\Models\Mosque;
use App\Services\Fundraising\PaymentMethods;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

/**
 * Creating or editing a campaign. The goal is typed in whole euros; dates are
 * days in the mosque's time zone. A way of giving can only be allowed once
 * the mosque's account for it is verified.
 */
class SaveCampaignRequest extends FormRequest
{
    public function authorize(): bool
    {
        $mosque = $this->route('mosque');

        return $mosque instanceof Mosque && (bool) $this->user()?->can('manage', $mosque);
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        $goalMin = intdiv((int) config('fundraising.goal_min'), 100);
        $goalMax = intdiv((int) config('fundraising.goal_max'), 100);

        return [
            'kind' => ['required', 'string', Rule::in(Campaign::KINDS)],
            'title' => ['required', 'string', PlainText::RULE, 'min:5', 'max:160'],
            'summary' => ['required', 'string', PlainText::RULE, 'min:10', 'max:300'],
            'story' => ['required', 'string', PlainText::RULE, 'min:20', 'max:20000'],
            'cover' => ['nullable', 'file', 'image', 'mimes:jpg,jpeg,png,webp', 'max:4096', 'dimensions:max_width=6000,max_height=6000'],
            'remove_cover' => ['boolean'],
            'goal' => ['required', 'integer', 'min:'.$goalMin, 'max:'.$goalMax],
            'starts_on' => ['nullable', 'date_format:Y-m-d'],
            'ends_on' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:today', 'after_or_equal:starts_on'],
            'allow_paypal' => ['boolean'],
            'allow_bank' => ['boolean'],
            'show_donor_names' => ['boolean'],
        ];
    }

    /** @return array<int, \Closure(Validator): void> */
    public function after(): array
    {
        return [function (Validator $validator) {
            $mosque = $this->route('mosque');
            if (! $mosque instanceof Mosque) {
                return;
            }
            $allowable = app(PaymentMethods::class)->allowable($mosque);
            if ($this->boolean('allow_paypal') && ! $allowable['paypal']) {
                $validator->errors()->add('allow_paypal', ui('fundraising.v_method_unverified'));
            }
            if ($this->boolean('allow_bank') && ! $allowable['bank']) {
                $validator->errors()->add('allow_bank', ui('fundraising.v_method_unverified'));
            }
        }];
    }

    /** @return array<string, string> */
    public function messages(): array
    {
        $range = ui('fundraising.v_goal_range', [
            'min' => number_format(intdiv((int) config('fundraising.goal_min'), 100), 0, ',', ' ').' €',
            'max' => number_format(intdiv((int) config('fundraising.goal_max'), 100), 0, ',', ' ').' €',
        ]);

        return [
            'goal.min' => $range,
            'goal.max' => $range,
            'ends_on.after_or_equal' => ui('fundraising.v_ends_on'),
        ];
    }

    /** @return array<string, string> */
    public function attributes(): array
    {
        return [
            'kind' => ui('fundraising.field_kind'),
            'title' => ui('fundraising.field_title'),
            'summary' => ui('fundraising.field_summary'),
            'story' => ui('fundraising.field_story'),
            'cover' => ui('fundraising.field_cover'),
            'goal' => ui('fundraising.field_goal'),
            'starts_on' => ui('fundraising.field_starts_on'),
            'ends_on' => ui('fundraising.field_ends_on'),
        ];
    }
}
