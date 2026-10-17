<?php

namespace App\Http\Requests\Manage;

use Closure;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

/** The new order of a mosque's blog categories: every one of its ids, once. */
class ReorderCategoriesRequest extends FormRequest
{
    use AuthorizesMosqueManagers;

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'ids' => ['required', 'array', 'max:100'],
            'ids.*' => ['required', 'integer', 'min:1', 'distinct'],
        ];
    }

    /** @return array<int, Closure> */
    public function after(): array
    {
        return [function (Validator $validator): void {
            if ($validator->errors()->isNotEmpty()) {
                return;
            }
            $own = $this->mosque()->postCategories()->pluck('id')->map(fn ($id) => (int) $id)->sort()->values()->all();
            $sent = collect((array) $this->input('ids'))->map(fn (mixed $id) => (int) $id)->sort()->values()->all();
            if ($own !== $sent) {
                $validator->errors()->add('ids', ui('manage.categories_changed'));
            }
        }];
    }
}
