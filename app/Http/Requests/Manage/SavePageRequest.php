<?php

namespace App\Http\Requests\Manage;

use App\Http\Controllers\MosquePage\Support\PlainText;
use App\Http\Controllers\MosquePage\Support\Slugs;
use App\Models\MosquePage;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/** Creating or editing a static page of a mosque's site. */
class SavePageRequest extends FormRequest
{
    use AuthorizesMosqueManagers;

    public const BODY_MAX = 50000;

    /** @return array<string, mixed> */
    public function rules(): array
    {
        $page = $this->route('page');

        return [
            'title' => ['required', 'string', PlainText::RULE, 'max:160'],
            'slug' => ['nullable', 'string', 'max:'.Slugs::PAGE_MAX, Slugs::RULE,
                Rule::unique('mosque_pages', 'slug')->where('mosque_id', $this->mosque()->id)
                    ->ignore($page instanceof MosquePage ? $page->id : null)],
            'body' => ['required', 'string', PlainText::RULE, 'max:'.self::BODY_MAX],
            'sort' => ['nullable', 'integer', 'min:0', 'max:999'],
            'show_in_menu' => ['boolean'],
            'published' => ['boolean'],
        ];
    }
}
