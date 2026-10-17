<?php

namespace App\Http\Requests\Manage;

use App\Http\Controllers\MosquePage\Support\PlainText;
use App\Http\Controllers\MosquePage\Support\Slugs;
use App\Http\Controllers\MosquePage\Support\VideoEmbed;
use App\Models\MosquePost;
use Carbon\CarbonImmutable;
use Closure;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

/** Creating or editing a post of a mosque's blog. */
class SavePostRequest extends FormRequest
{
    use AuthorizesMosqueManagers;

    public const BODY_MAX = 30000;

    public const STATUSES = ['draft', 'scheduled', 'published'];

    /** @return array<string, mixed> */
    public function rules(): array
    {
        $mosque = $this->mosque();
        $post = $this->route('post');
        $dateTime = 'date_format:Y-m-d\TH:i';

        return [
            'type' => ['sometimes', 'required', 'string', Rule::in(MosquePost::TYPES)],
            'category_id' => ['nullable', 'integer', 'min:1',
                Rule::exists('mosque_post_categories', 'id')->where('mosque_id', $mosque->id)],
            'title' => ['required', 'string', PlainText::RULE, 'max:200'],
            'slug' => ['nullable', 'string', 'max:'.Slugs::POST_MAX, Slugs::RULE,
                Rule::unique('mosque_posts', 'slug')->where('mosque_id', $mosque->id)
                    ->ignore($post instanceof MosquePost ? $post->id : null)],
            'excerpt' => ['nullable', 'string', PlainText::RULE, 'max:400'],
            'body' => ['required', 'string', PlainText::RULE, 'max:'.self::BODY_MAX],
            'image' => ['nullable', 'file', 'image', 'mimes:jpg,jpeg,png,webp', 'max:4096',
                'dimensions:max_width=6000,max_height=6000'],
            'remove_image' => ['boolean'],
            'video_url' => ['nullable', 'string', 'max:500', function (string $attribute, mixed $value, Closure $fail) {
                if (VideoEmbed::parse(is_string($value) ? $value : null) === null) {
                    $fail(ui('manage.video_invalid'));
                }
            }],
            'attachment' => ['nullable', 'file', 'mimes:pdf', 'mimetypes:application/pdf', 'max:10240'],
            'remove_attachment' => ['boolean'],
            'event_starts_at' => ['nullable', 'required_if:type,event', $dateTime],
            'pinned' => ['boolean'],
            'status' => ['nullable', 'string', Rule::in(self::STATUSES)],
            'publish' => ['boolean'],
            'publish_at' => ['nullable', 'required_if:status,scheduled', $dateTime],
        ];
    }

    /**
     * A scheduled date must still be ahead (in the mosque's own time zone).
     *
     * @return array<int, Closure>
     */
    public function after(): array
    {
        return [function (Validator $validator): void {
            if ($validator->errors()->has('publish_at') || $this->input('status') !== 'scheduled') {
                return;
            }
            $at = CarbonImmutable::createFromFormat('Y-m-d\TH:i', (string) $this->input('publish_at'), $this->mosque()->timezone);
            if (! $at || ! $at->isFuture()) {
                $validator->errors()->add('publish_at', ui('manage.schedule_in_future'));
            }
        }];
    }

    public function status(): string
    {
        $status = $this->input('status');

        return in_array($status, self::STATUSES, true) ? $status : ($this->boolean('publish') ? 'published' : 'draft');
    }
}
