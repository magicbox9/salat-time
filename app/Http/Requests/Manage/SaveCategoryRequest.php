<?php

namespace App\Http\Requests\Manage;

use App\Http\Controllers\MosquePage\Support\PlainText;
use App\Models\MosquePostCategory;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/** Creating or renaming a blog category. */
class SaveCategoryRequest extends FormRequest
{
    use AuthorizesMosqueManagers;

    /** @return array<string, mixed> */
    public function rules(): array
    {
        $category = $this->route('postCategory');

        return [
            'name' => ['required', 'string', PlainText::RULE, 'min:2', 'max:80',
                Rule::unique('mosque_post_categories', 'name')
                    ->where('mosque_id', $this->mosque()->id)
                    ->ignore($category instanceof MosquePostCategory ? $category->id : null)],
            'description' => ['nullable', 'string', PlainText::RULE, 'max:300'],
        ];
    }
}
