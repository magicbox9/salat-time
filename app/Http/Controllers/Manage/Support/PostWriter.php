<?php

namespace App\Http\Controllers\Manage\Support;

use App\Http\Controllers\MosquePage\Support\Slugs;
use App\Http\Controllers\MosquePage\Support\VideoEmbed;
use App\Http\Requests\Manage\SavePostRequest;
use App\Models\Mosque;
use App\Models\MosquePost;
use Carbon\CarbonImmutable;
use Carbon\CarbonInterface;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Throwable;

/**
 * Saves a post from the management form: text, address, category, cover,
 * khutbah video, PDF and when it goes public. Files are written first and
 * the old ones removed only once the post points to the new ones.
 */
class PostWriter
{
    public function __construct(private ImageStore $images, private AttachmentStore $attachments) {}

    public function save(MosquePost $post, SavePostRequest $request, Mosque $mosque): void
    {
        $data = $request->validated();
        $type = $data['type'] ?? $post->type ?? 'news';
        $zone = $mosque->timezone;

        $post->fill([
            'type' => $type,
            'category_id' => $data['category_id'] ?? null,
            'title' => $data['title'],
            'excerpt' => filled($data['excerpt'] ?? null) ? trim($data['excerpt']) : null,
            'body' => $data['body'],
            'video_url' => VideoEmbed::parse($data['video_url'] ?? null)['url'] ?? null,
            'pinned' => $request->boolean('pinned'),
            'event_starts_at' => $type === 'event' && ! empty($data['event_starts_at'])
                ? CarbonImmutable::createFromFormat('Y-m-d\TH:i', $data['event_starts_at'], $zone)->utc()
                : null,
            'published_at' => $this->publishedAt($post, $request->status(), $data['publish_at'] ?? null, $zone),
        ]);
        $wanted = $data['slug'] ?? null;
        $post->slug = filled($wanted) ? $wanted : ($post->slug ?: $this->freeSlug($post, $mosque));

        $oldImage = $post->image_path;
        $oldAttachment = $post->attachment_path;
        $stored = [];

        try {
            if ($request->hasFile('image')) {
                $post->image_path = $stored['image'] = $this->images->store($mosque, $request->file('image'), 'image', 'posts', 1600);
            } elseif ($request->boolean('remove_image')) {
                $post->image_path = null;
            }

            if ($request->hasFile('attachment')) {
                $file = $this->attachments->store($mosque, $request->file('attachment'), 'attachment');
                $post->attachment_path = $stored['attachment'] = $file['path'];
                $post->attachment_name = $file['name'];
            } elseif ($request->boolean('remove_attachment')) {
                $post->attachment_path = null;
                $post->attachment_name = null;
            }

            $this->persist($post, $mosque, filled($wanted));
        } catch (Throwable $e) {
            $this->images->delete($mosque, $stored['image'] ?? null);
            $this->attachments->delete($mosque, $stored['attachment'] ?? null);

            throw $e;
        }

        if ($oldImage !== null && $oldImage !== $post->image_path) {
            $this->images->delete($mosque, $oldImage);
        }
        if ($oldAttachment !== null && $oldAttachment !== $post->attachment_path) {
            $this->attachments->delete($mosque, $oldAttachment);
        }
    }

    /** Deletes the post's files at once and frees its address; the record is soft-deleted. */
    public function delete(MosquePost $post, Mosque $mosque): void
    {
        $this->images->delete($mosque, $post->image_path);
        $this->attachments->delete($mosque, $post->attachment_path);
        $post->forceFill([
            'image_path' => null,
            'attachment_path' => null,
            'attachment_name' => null,
            'slug' => $post->slug ? Slugs::retired($post->slug, $post->id, Slugs::POST_MAX) : null,
        ])->save();
        $post->delete();
    }

    private function publishedAt(MosquePost $post, string $status, ?string $publishAt, string $zone): ?CarbonInterface
    {
        $current = $post->getAttribute('published_at');

        return match ($status) {
            // Already public: keep its original date. A scheduled post published now: today.
            'published' => $current instanceof CarbonInterface && ! $current->isFuture() ? $current : now(),
            'scheduled' => CarbonImmutable::createFromFormat('Y-m-d\TH:i', (string) $publishAt, $zone)->utc(),
            default => null,
        };
    }

    private function freeSlug(MosquePost $post, Mosque $mosque): string
    {
        return Slugs::unique('mosque_posts', $mosque->id,
            Slugs::base($post->title, 'post', Slugs::POST_MAX), $post->exists ? $post->id : null, Slugs::POST_MAX);
    }

    /**
     * Saves. When two posts take the same address at the same moment, the
     * later one gets the next free automatic address or, when the manager
     * chose it, goes back to the form with a message (never a server error).
     * The first attempt runs in its own savepoint, so a refused insert never
     * leaves an enclosing transaction aborted.
     */
    private function persist(MosquePost $post, Mosque $mosque, bool $chosenSlug): void
    {
        try {
            DB::transaction(fn () => $post->save());
        } catch (UniqueConstraintViolationException) {
            if ($chosenSlug) {
                throw ValidationException::withMessages(['slug' => ui('manage.slug_taken')]);
            }
            $post->slug = $this->freeSlug($post, $mosque);
            $post->save();
        }
    }
}
