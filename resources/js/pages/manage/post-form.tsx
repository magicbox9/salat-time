import { Link, useForm } from '@inertiajs/react';
import { Field, FormSection, Textarea } from '@/components/manage/fields';
import { ImageField } from '@/components/manage/image-field';
import { ManageHeader } from '@/components/manage/manage-header';
import { PostTypePicker } from '@/components/manage/post-type-picker';
import type { PostType } from '@/components/mosque/types';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Spinner } from '@/components/ui/spinner';
import { useT } from '@/lib/i18n';
import type { MosqueSummary } from '@/types/mosque';

type EditablePost = {
    id: number;
    type: PostType;
    title: string;
    body: string;
    image_url: string | null;
    event_starts_at: string;
    pinned: boolean;
    published: boolean;
};

type Props = {
    mosque: MosqueSummary;
    post: EditablePost | null;
    types: PostType[];
};

/** Writing or editing a post: publish now or keep it as a draft. */
export default function PostForm({ mosque, post, types }: Props) {
    const t = useT();
    const editing = post !== null;
    const form = useForm({
        type: post?.type ?? ('news' as PostType),
        title: post?.title ?? '',
        body: post?.body ?? '',
        event_starts_at: post?.event_starts_at ?? '',
        pinned: post?.pinned ?? false,
        image: null as File | null,
        remove_image: false,
    });
    const { data, setData, errors, processing } = form;

    const save = (publish: boolean) => {
        form.transform((current) => ({
            ...current,
            event_starts_at:
                current.type === 'event' ? current.event_starts_at : '',
            publish,
            ...(editing ? { _method: 'put' } : {}),
        }));
        form.post(
            editing
                ? `/manage/${mosque.slug}/posts/${post.id}`
                : `/manage/${mosque.slug}/posts`,
            {
                forceFormData: true,
                preserveScroll: true,
            },
        );
    };

    return (
        <div className="mx-auto max-w-3xl space-y-6">
            <ManageHeader
                mosque={mosque}
                title={editing ? t('manage.edit_post') : t('manage.new_post')}
            />

            <form
                onSubmit={(event) => {
                    event.preventDefault();
                    save(true);
                }}
                className="space-y-6"
            >
                <FormSection title={t('manage.post_kind')}>
                    <PostTypePicker
                        types={types}
                        value={data.type}
                        onChange={(type) => setData('type', type)}
                    />
                    {errors.type && (
                        <p className="text-sm text-red-600 dark:text-red-400">
                            {errors.type}
                        </p>
                    )}
                </FormSection>

                <FormSection title={t('manage.post_content')}>
                    <Field
                        id="title"
                        label={t('manage.post_title')}
                        error={errors.title}
                    >
                        <Input
                            id="title"
                            value={data.title}
                            maxLength={200}
                            required
                            onChange={(event) =>
                                setData('title', event.target.value)
                            }
                            aria-invalid={errors.title ? true : undefined}
                        />
                    </Field>

                    {data.type === 'event' && (
                        <Field
                            id="event_starts_at"
                            label={t('manage.event_starts_at')}
                            hint={t('manage.event_hint', {
                                timezone: mosque.timezone,
                            })}
                            error={errors.event_starts_at}
                        >
                            <Input
                                id="event_starts_at"
                                type="datetime-local"
                                dir="ltr"
                                required
                                value={data.event_starts_at}
                                onChange={(event) =>
                                    setData(
                                        'event_starts_at',
                                        event.target.value,
                                    )
                                }
                                className="sm:w-64"
                            />
                        </Field>
                    )}

                    <Field
                        id="body"
                        label={t('manage.post_body')}
                        hint={t('manage.post_body_hint')}
                        error={errors.body}
                    >
                        <Textarea
                            id="body"
                            rows={10}
                            maxLength={10000}
                            required
                            value={data.body}
                            onChange={(event) =>
                                setData('body', event.target.value)
                            }
                            aria-invalid={errors.body ? true : undefined}
                        />
                        <span
                            className="text-end text-xs text-muted-foreground tabular-nums"
                            dir="ltr"
                        >
                            {data.body.length}/10000
                        </span>
                    </Field>

                    <ImageField
                        label={t('manage.post_image')}
                        hint={t('manage.post_image_hint')}
                        currentUrl={post?.image_url ?? null}
                        file={data.image}
                        removed={data.remove_image}
                        onFile={(file) => setData('image', file)}
                        onRemove={(removed) => setData('remove_image', removed)}
                        error={errors.image}
                    />

                    <div className="flex items-start gap-2">
                        <Checkbox
                            id="pinned"
                            checked={data.pinned}
                            onCheckedChange={(checked) =>
                                setData('pinned', checked === true)
                            }
                        />
                        <div className="grid gap-0.5">
                            <Label htmlFor="pinned" className="font-normal">
                                {t('manage.pin')}
                            </Label>
                            <p className="text-xs text-muted-foreground">
                                {t('manage.pin_hint')}
                            </p>
                        </div>
                    </div>
                </FormSection>

                <div className="flex flex-col-reverse gap-2 sm:flex-row sm:items-center sm:justify-between">
                    <Button asChild variant="ghost">
                        <Link href={`/manage/${mosque.slug}/posts`}>
                            {t('manage.cancel')}
                        </Link>
                    </Button>
                    <div className="flex flex-col-reverse gap-2 sm:flex-row">
                        <Button
                            type="button"
                            variant="outline"
                            disabled={processing}
                            onClick={() => save(false)}
                        >
                            {editing && post.published
                                ? t('manage.unpublish')
                                : t('manage.save_draft')}
                        </Button>
                        <Button type="submit" disabled={processing}>
                            {processing && <Spinner />}
                            {editing && post.published
                                ? t('manage.update')
                                : t('manage.publish')}
                        </Button>
                    </div>
                </div>
            </form>
        </div>
    );
}
