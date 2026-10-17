import { Link, useForm } from '@inertiajs/react';
import { ExternalLink } from 'lucide-react';
import { useState } from 'react';
import { Field, FormSection } from '@/components/manage/fields';
import { ManageLayout } from '@/components/manage/manage-layout';
import { MarkdownEditor } from '@/components/manage/markdown-editor';
import { SlugField, slugify, trimSlug } from '@/components/manage/slug-field';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Spinner } from '@/components/ui/spinner';
import { useT } from '@/lib/i18n';
import type { MosqueSummary } from '@/types/mosque';

type EditablePage = {
    id: number;
    title: string;
    slug: string;
    body: string;
    sort: number;
    show_in_menu: boolean;
    published: boolean;
    url: string;
};

type Props = {
    mosque: MosqueSummary;
    page: EditablePage | null;
    nextSort: number;
    limits: { body: number };
};

/** Writing or editing a page of the mosque's site. */
export default function PageForm({ mosque, page, nextSort, limits }: Props) {
    const t = useT();
    const editing = page !== null;
    const [slugTouched, setSlugTouched] = useState(editing);
    const form = useForm({
        title: page?.title ?? '',
        slug: page?.slug ?? '',
        body: page?.body ?? '',
        sort: String(page?.sort ?? nextSort),
        show_in_menu: page?.show_in_menu ?? true,
        published: page?.published ?? true,
    });
    const { data, setData, errors, processing } = form;

    const submit = (event: React.FormEvent) => {
        event.preventDefault();
        const url = editing
            ? `/manage/${mosque.slug}/pages/${page.id}`
            : `/manage/${mosque.slug}/pages`;
        form.transform((current) => ({
            ...current,
            slug: trimSlug(current.slug),
        }));

        if (editing) {
            form.put(url, { preserveScroll: true });
        } else {
            form.post(url, { preserveScroll: true });
        }
    };

    return (
        <ManageLayout
            mosque={mosque}
            title={editing ? t('manage.edit_page') : t('manage.new_page')}
            actions={
                editing && (
                    <Button asChild variant="outline" size="sm">
                        <Link href={page.url}>
                            <ExternalLink className="size-4" aria-hidden />
                            {page.published
                                ? t('manage.view_page')
                                : t('manage.preview_post')}
                        </Link>
                    </Button>
                )
            }
        >
            <form onSubmit={submit} className="space-y-6">
                <FormSection title={t('manage.page_content')}>
                    <Field
                        id="title"
                        label={t('manage.page_title')}
                        error={errors.title}
                    >
                        <Input
                            id="title"
                            value={data.title}
                            maxLength={160}
                            required
                            dir="auto"
                            className="text-base font-medium"
                            onChange={(event) =>
                                setData((current) => ({
                                    ...current,
                                    title: event.target.value,
                                    slug: slugTouched
                                        ? current.slug
                                        : slugify(event.target.value, 160),
                                }))
                            }
                            aria-invalid={errors.title ? true : undefined}
                        />
                    </Field>
                    <SlugField
                        prefix={`/mosques/${mosque.slug}/pages/`}
                        value={data.slug}
                        max={160}
                        error={errors.slug}
                        onChange={(value) => {
                            setSlugTouched(true);
                            setData('slug', value);
                        }}
                    />
                    <Field
                        id="body"
                        label={t('manage.page_body')}
                        error={errors.body}
                    >
                        <MarkdownEditor
                            id="body"
                            value={data.body}
                            onChange={(value) => setData('body', value)}
                            mosqueSlug={mosque.slug}
                            maxLength={limits.body}
                            rows={18}
                            invalid={Boolean(errors.body)}
                            required
                        />
                    </Field>
                </FormSection>

                <FormSection title={t('manage.page_visibility')}>
                    <div className="flex items-start gap-2">
                        <Checkbox
                            id="published"
                            checked={data.published}
                            onCheckedChange={(checked) =>
                                setData('published', checked === true)
                            }
                        />
                        <div className="grid gap-0.5">
                            <Label htmlFor="published" className="font-normal">
                                {t('manage.page_published')}
                            </Label>
                            <p className="text-xs text-muted-foreground">
                                {t('manage.page_published_hint')}
                            </p>
                        </div>
                    </div>
                    <div className="flex items-start gap-2">
                        <Checkbox
                            id="show_in_menu"
                            checked={data.show_in_menu}
                            onCheckedChange={(checked) =>
                                setData('show_in_menu', checked === true)
                            }
                        />
                        <div className="grid gap-0.5">
                            <Label
                                htmlFor="show_in_menu"
                                className="font-normal"
                            >
                                {t('manage.page_in_menu')}
                            </Label>
                            <p className="text-xs text-muted-foreground">
                                {t('manage.page_in_menu_hint')}
                            </p>
                        </div>
                    </div>
                    <Field
                        id="sort"
                        label={t('manage.menu_order')}
                        hint={t('manage.menu_order_hint')}
                        error={errors.sort}
                        className="sm:w-48"
                    >
                        <Input
                            id="sort"
                            type="number"
                            min={0}
                            max={999}
                            dir="ltr"
                            value={data.sort}
                            onChange={(event) =>
                                setData('sort', event.target.value)
                            }
                        />
                    </Field>
                </FormSection>

                <div className="flex flex-col-reverse gap-2 sm:flex-row sm:items-center sm:justify-between">
                    <Button asChild variant="ghost">
                        <Link href={`/manage/${mosque.slug}/pages`}>
                            {t('manage.cancel')}
                        </Link>
                    </Button>
                    <Button type="submit" disabled={processing} size="lg">
                        {processing && <Spinner />}
                        {editing ? t('manage.update') : t('manage.create_page')}
                    </Button>
                </div>
            </form>
        </ManageLayout>
    );
}
