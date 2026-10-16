<?php

namespace App\Http\Requests\Manage;

use App\Http\Controllers\MosquePage\Support\PlainText;
use App\Models\Mosque;
use Illuminate\Foundation\Http\FormRequest;

/**
 * What a mosque's managers may change on its page. Name, address, coordinates
 * and verification are not here on purpose: only an admin changes those.
 */
class UpdateMosqueRequest extends FormRequest
{
    /** Columns a manager may write besides the images (everything else is ignored). */
    public const FIELDS = [
        'description', 'association', 'website', 'phone', 'email', 'jumua', 'jumua2', 'jumua3', 'jumua_as_dhuhr',
    ];

    public function authorize(): bool
    {
        $mosque = $this->route('mosque');

        return $mosque instanceof Mosque && (bool) $this->user()?->can('manage', $mosque);
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        $time = ['nullable', 'date_format:H:i'];
        $image = ['nullable', 'file', 'image', 'mimes:jpg,jpeg,png,webp', 'max:4096', 'dimensions:max_width=6000,max_height=6000'];

        return [
            'description' => ['nullable', 'string', PlainText::RULE, 'max:5000'],
            'association' => ['nullable', 'string', PlainText::RULE, 'max:200'],
            'website' => ['nullable', 'string', PlainText::RULE, 'max:300', 'url:http,https'],
            'phone' => ['nullable', 'string', 'max:40', 'regex:/^[0-9+().\/\s-]{4,40}$/'],
            'email' => ['nullable', 'string', PlainText::RULE, 'max:200', 'email'],
            'jumua' => $time,
            'jumua2' => $time,
            'jumua3' => $time,
            'jumua_as_dhuhr' => ['boolean'],
            'logo' => $image,
            'cover' => $image,
            'remove_logo' => ['boolean'],
            'remove_cover' => ['boolean'],
        ];
    }
}
