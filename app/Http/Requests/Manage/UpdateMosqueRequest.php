<?php

namespace App\Http\Requests\Manage;

use App\Http\Controllers\MosquePage\Support\AccentColor;
use App\Http\Controllers\MosquePage\Support\PlainText;
use App\Http\Controllers\MosquePage\Support\SocialLinks;
use Closure;
use Illuminate\Foundation\Http\FormRequest;

/**
 * What a mosque's managers may change on its site. Name, address, coordinates
 * and verification are not here on purpose: only an admin changes those.
 */
class UpdateMosqueRequest extends FormRequest
{
    use AuthorizesMosqueManagers;

    /** Columns a manager may write besides the images and social links (everything else is ignored). */
    public const FIELDS = [
        'description', 'association', 'website', 'phone', 'email', 'jumua', 'jumua2', 'jumua3', 'jumua_as_dhuhr',
        'tagline', 'accent_color',
    ];

    /** @return array<string, mixed> */
    public function rules(): array
    {
        $time = ['nullable', 'date_format:H:i'];
        $image = ['nullable', 'file', 'image', 'mimes:jpg,jpeg,png,webp', 'max:4096', 'dimensions:max_width=6000,max_height=6000'];
        $rules = [
            'description' => ['nullable', 'string', PlainText::RULE, 'max:5000'],
            'tagline' => ['nullable', 'string', PlainText::RULE, 'max:200'],
            'accent_color' => ['nullable', 'string', 'regex:'.AccentColor::PATTERN],
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
            'social_links' => ['sometimes', 'nullable', 'array:'.implode(',', SocialLinks::NETWORKS)],
        ];

        foreach (SocialLinks::NETWORKS as $network) {
            $rules["social_links.$network"] = ['nullable', 'string', 'max:300', function (string $attribute, mixed $value, Closure $fail) use ($network) {
                if (SocialLinks::normalize($network, is_string($value) ? $value : null) === null) {
                    $fail(ui('manage.social_invalid', ['network' => ui('mosquesite.social_'.$network)]));
                }
            }];
        }

        return $rules;
    }

    /**
     * The social links as stored: canonical https addresses, empty ones dropped.
     *
     * @return array<string, string>
     */
    public function socialLinks(): array
    {
        $links = [];
        foreach (SocialLinks::NETWORKS as $network) {
            $url = SocialLinks::normalize($network, $this->validated('social_links.'.$network));
            if ($url !== null) {
                $links[$network] = $url;
            }
        }

        return $links;
    }
}
