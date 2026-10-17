<?php

namespace App\Http\Requests\Manage;

use App\Http\Controllers\MosquePage\Support\PlainText;
use Illuminate\Foundation\Http\FormRequest;

/** Text from the Markdown editor, to be shown as it will appear. */
class MarkdownPreviewRequest extends FormRequest
{
    use AuthorizesMosqueManagers;

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'body' => ['present', 'nullable', 'string', PlainText::RULE, 'max:'.SavePageRequest::BODY_MAX],
        ];
    }
}
