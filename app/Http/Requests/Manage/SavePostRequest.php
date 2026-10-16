<?php

namespace App\Http\Requests\Manage;

use App\Http\Controllers\MosquePage\Support\PlainText;
use App\Models\Mosque;
use App\Models\MosquePost;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/** Creating or editing a post on a mosque's page. */
class SavePostRequest extends FormRequest
{
    public function authorize(): bool
    {
        $mosque = $this->route('mosque');

        return $mosque instanceof Mosque && (bool) $this->user()?->can('manage', $mosque);
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'type' => ['required', 'string', Rule::in(MosquePost::TYPES)],
            'title' => ['required', 'string', PlainText::RULE, 'max:200'],
            'body' => ['required', 'string', PlainText::RULE, 'max:10000'],
            'image' => ['nullable', 'file', 'image', 'mimes:jpg,jpeg,png,webp', 'max:4096',
                'dimensions:max_width=6000,max_height=6000'],
            'remove_image' => ['boolean'],
            'event_starts_at' => ['nullable', 'required_if:type,event', 'date_format:Y-m-d\TH:i'],
            'pinned' => ['boolean'],
            'publish' => ['boolean'],
        ];
    }
}
