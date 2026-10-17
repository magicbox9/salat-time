import { Link, useForm } from '@inertiajs/react';
import { ExternalLink } from 'lucide-react';
import { useState } from 'react';
import { Field, FormSection, Textarea } from '@/components/manage/fields';
import { ManageLayout } from '@/components/manage/manage-layout';
import { MarkdownEditor } from '@/components/manage/markdown-editor';
import type {
    CategoryOption,
    EditablePost,
    PostFormData,
} from '@/components/manage/post-form-types';
import { PostSettings } from '@/components/manage/post-settings';
import { PublishPanel } from '@/components/manage/publish-panel';
import { SlugField, slugify, trimSlug } from '@/components/manage/slug-field';
import type { PostType } from '@/components/mosque/types';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Spinner } from '@/components/ui/spinner';
import { useT } from '@/lib/i18n';
import type { MosqueSummary } from '@/types/mosque';

type Props = {
    mosque: MosqueSummary;
    post: EditablePost | null;
    types: PostType[];
    categories: CategoryOption[];
    limits: { body: number; attachment_mb: number };
};

/** Writing or editing a post: Markdown text, address, category, media, publication. */
export default function PostForm({
    mosque,
    post,
    types,
    categories,
    limits,
}: Props) {
    const t = useT();
    const editing = post !== null;
    const [slugTouched, setSlugTouched] = useState(editing);
    const form = useForm<PostFormData>({
        type: post?.type ?? 'news',
        category_id: post?.category_id ? String(post.category_id) : '',
        title: post?.title ?? '',
        slug: post?.slug ?? '',
        excerpt: post?.excerpt ?? '',
        body: post?.body ?? '',
        video_url: post?.video_url ?? '',
        event_starts_at: post?.event_starts_at ?? '',
        pinned: post?.pinned ?? false,
        status: post?.status ?? 'published',
        publish_at: post?.publish_at ?? '',
        image: null,
        remove_image: false,
        attachment: null,
        remove_attachment: false,
    });
    const { data, setData, errors, processing } = form;

    const submit = (event: React.FormEvent) => {
        event.preventDefault();
        form.transform((current) => ({
            ...current,
            // "my-post-" typed and submitted without leaving the field: the server wants "my-post".
            slug: trimSlug(current.slug),
            category_id: current.category_id || null,
            event_starts_at:
                current.type === 'event' ? current.event_starts_at : '',
            publish_at:
                current.status === 'scheduled' ? current.publish_at : '',
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

    const submitLabel =
        data.status === 'draft'
            ? t('manage.save_draft')
            : data.status === 'scheduled'
              ? t('manage.schedule')
              : editing && post.published
                ? t('manage.update')
                : t('manage.publish');

    return (
        <ManageLayout
            mosque={mosque}
            title={editing ? t('manage.edit_post') : t('manage.new_post')}
            actions={
                editing && (
                    <Button asChild variant="outline" size="sm">
                        <Link href={post.url}>
                            <ExternalLink className="size-4" aria-hidden />
                            {post.published
                                ? t('manage.view_post')
                                : t('manage.preview_post')}
                        </Link>
                    </Button>
                )
            }
        >
            <form
                onSubmit={submit}
                className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_22rem] xl:items-start"
            >
                <div className="min-w-0 space-y-6">
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
                                dir="auto"
                                className="text-base font-medium"
                                onChange={(event) => {
                                    setData((current) => ({
                                        ...current,
                                        title: event.target.value,
                                        slug: slugTouched
                                            ? current.slug
                                            : slugify(event.target.value),
                                    }));
                                }}
                                aria-invalid={errors.title ? true : undefined}
                            />
                        </Field>
                        <SlugField
                            prefix={`/mosques/${mosque.slug}/blog/`}
                            value={data.slug}
                            max={200}
                            error={errors.slug}
                            onChange={(value) => {
                                setSlugTouched(true);
                                setData('slug', value);
                            }}
                        />
                        <Field
                            id="excerpt"
                            label={t('manage.excerpt')}
                            hint={t('manage.excerpt_hint')}
                            error={errors.excerpt}
                        >
                            <Textarea
                                id="excerpt"
                                rows={2}
                                maxLength={400}
                                dir="auto"
                                className="min-h-16"
                                value={data.excerpt}
                                onChange={(event) =>
                                    setData('excerpt', event.target.value)
                                }
                            />
                        </Field>
                        <Field
                            id="body"
                            label={t('manage.post_body')}
                            error={errors.body}
                        >
                            <MarkdownEditor
                                id="body"
                                value={data.body}
                                onChange={(value) => setData('body', value)}
                                mosqueSlug={mosque.slug}
                                maxLength={limits.body}
                                invalid={Boolean(errors.body)}
                                required
                            />
                        </Field>
                    </FormSection>

                    <FormSection title={t('manage.publication')}>
                        <PublishPanel
                            status={data.status}
                            publishAt={data.publish_at}
                            timezone={mosque.timezone}
                            wasPublished={editing && post.published}
                            onStatus={(status) => setData('status', status)}
                            onPublishAt={(value) =>
                                setData('publish_at', value)
                            }
                            error={errors.publish_at ?? errors.status}
                        />
                    </FormSection>
                </div>

                <div className="min-w-0 space-y-6 xl:sticky xl:top-24">
                    <PostSettings
                        form={form}
                        post={post}
                        mosqueSlug={mosque.slug}
                        timezone={mosque.timezone}
                        types={types}
                        categories={categories}
                        attachmentMb={limits.attachment_mb}
                    />
                </div>

                <div className="flex flex-col-reverse gap-2 sm:flex-row sm:items-center sm:justify-between xl:col-span-2">
                    <Button asChild variant="ghost">
                        <Link href={`/manage/${mosque.slug}/posts`}>
                            {t('manage.cancel')}
                        </Link>
                    </Button>
                    <Button type="submit" disabled={processing} size="lg">
                        {processing && <Spinner />}
                        {submitLabel}
                    </Button>
                </div>
            </form>
        </ManageLayout>
    );
}
