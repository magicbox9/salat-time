import type { InertiaFormProps } from '@inertiajs/react';
import { Link } from '@inertiajs/react';
import { Tags } from 'lucide-react';
import type { PostType } from '@/components/mosque/types';
import { Checkbox } from '@/components/ui/checkbox';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { useT } from '@/lib/i18n';
import { AttachmentField } from './attachment-field';
import { Field, FormSection } from './fields';
import { ImageField } from './image-field';
import type {
    CategoryOption,
    EditablePost,
    PostFormData,
} from './post-form-types';
import { PostTypePicker } from './post-type-picker';

type Props = {
    form: InertiaFormProps<PostFormData>;
    post: EditablePost | null;
    mosqueSlug: string;
    timezone: string;
    types: PostType[];
    categories: CategoryOption[];
    attachmentMb: number;
};

const selectClass =
    'h-9 w-full rounded-md border border-input bg-transparent px-3 text-sm shadow-xs outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 dark:bg-input/30';

/** Category, kind, picture, khutbah video, PDF and pin: the details around the text. */
export function PostSettings({
    form,
    post,
    mosqueSlug,
    timezone,
    types,
    categories,
    attachmentMb,
}: Props) {
    const t = useT();
    const { data, setData, errors } = form;

    return (
        <>
            <FormSection title={t('manage.post_classify')}>
                <Field
                    id="category_id"
                    label={t('manage.category')}
                    error={errors.category_id}
                >
                    <select
                        id="category_id"
                        className={selectClass}
                        value={data.category_id}
                        onChange={(event) =>
                            setData('category_id', event.target.value)
                        }
                    >
                        <option value="">{t('manage.uncategorised')}</option>
                        {categories.map((category) => (
                            <option
                                key={category.id}
                                value={String(category.id)}
                            >
                                {category.name}
                            </option>
                        ))}
                    </select>
                </Field>
                <Link
                    href={`/manage/${mosqueSlug}/categories`}
                    className="-mt-3 inline-flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground hover:underline"
                >
                    <Tags className="size-3.5" aria-hidden />
                    {t('manage.manage_categories')}
                </Link>

                <div className="grid gap-2">
                    <p className="text-sm font-medium">
                        {t('manage.post_kind')}
                    </p>
                    <PostTypePicker
                        types={types}
                        value={data.type}
                        onChange={(type) => setData('type', type)}
                    />
                </div>

                {data.type === 'event' && (
                    <Field
                        id="event_starts_at"
                        label={t('manage.event_starts_at')}
                        hint={t('manage.event_hint', { timezone })}
                        error={errors.event_starts_at}
                    >
                        <Input
                            id="event_starts_at"
                            type="datetime-local"
                            dir="ltr"
                            required
                            value={data.event_starts_at}
                            onChange={(event) =>
                                setData('event_starts_at', event.target.value)
                            }
                            className="sm:w-64"
                        />
                    </Field>
                )}

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

            <FormSection title={t('manage.post_media')}>
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
                <Field
                    id="video_url"
                    label={t('manage.video_url')}
                    hint={t('manage.video_hint')}
                    error={errors.video_url}
                >
                    <Input
                        id="video_url"
                        type="url"
                        dir="ltr"
                        inputMode="url"
                        placeholder="https://www.youtube.com/watch?v=…"
                        maxLength={500}
                        value={data.video_url}
                        onChange={(event) =>
                            setData('video_url', event.target.value)
                        }
                        aria-invalid={errors.video_url ? true : undefined}
                    />
                </Field>
                <AttachmentField
                    current={post?.attachment ?? null}
                    file={data.attachment}
                    removed={data.remove_attachment}
                    maxMb={attachmentMb}
                    onFile={(file) => setData('attachment', file)}
                    onRemove={(removed) =>
                        setData('remove_attachment', removed)
                    }
                    error={errors.attachment}
                />
            </FormSection>
        </>
    );
}
