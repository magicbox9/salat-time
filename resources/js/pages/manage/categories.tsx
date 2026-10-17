import { router, useForm } from '@inertiajs/react';
import { Plus } from 'lucide-react';
import { useEffect, useState } from 'react';
import { toast } from 'sonner';
import InputError from '@/components/input-error';
import { CategoryRow } from '@/components/manage/category-row';
import type { ManagedCategory } from '@/components/manage/category-row';
import { FormSection } from '@/components/manage/fields';
import { ManageLayout } from '@/components/manage/manage-layout';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { useT } from '@/lib/i18n';
import type { MosqueSummary } from '@/types/mosque';

type Props = {
    mosque: MosqueSummary;
    categories: ManagedCategory[];
    max: number;
};

/** The blog's categories: create, rename, reorder, delete. */
export default function ManageCategories({ mosque, categories, max }: Props) {
    const t = useT();
    const base = `/manage/${mosque.slug}/categories`;
    const [order, setOrder] = useState(categories);
    const [busy, setBusy] = useState(false);
    const form = useForm({ name: '', description: '' });

    useEffect(() => setOrder(categories), [categories]);

    const move = (index: number, direction: -1 | 1) => {
        const next = [...order];
        const [item] = next.splice(index, 1);
        next.splice(index + direction, 0, item);
        setOrder(next);
        router.put(
            `${base}/order`,
            { ids: next.map((c) => c.id) },
            {
                preserveScroll: true,
                onStart: () => setBusy(true),
                onFinish: () => setBusy(false),
                // Refused (the list changed meanwhile): back to the saved order, and say why.
                onError: (errors) => {
                    setOrder(categories);
                    toast.error(errors.ids ?? t('site.error_generic'));
                },
                // Too many moves in a row, or a server error: no error dialog, just a message.
                onHttpException: (response) => {
                    setOrder(categories);
                    toast.error(
                        response.status === 429
                            ? t('mosque.too_many')
                            : t('site.error_generic'),
                    );

                    return false;
                },
            },
        );
    };

    const create = (event: React.FormEvent) => {
        event.preventDefault();
        form.post(base, {
            preserveScroll: true,
            onSuccess: () => form.reset(),
        });
    };

    return (
        <ManageLayout
            mosque={mosque}
            title={t('manage.categories_title')}
            description={t('manage.categories_intro')}
        >
            <FormSection title={t('manage.new_category')}>
                <form
                    onSubmit={create}
                    className="grid gap-3 sm:grid-cols-[1fr_1.4fr_auto] sm:items-end"
                >
                    <div className="grid gap-1.5">
                        <Label htmlFor="new-category">
                            {t('manage.category_name')}
                        </Label>
                        <Input
                            id="new-category"
                            value={form.data.name}
                            maxLength={80}
                            required
                            disabled={order.length >= max}
                            onChange={(event) =>
                                form.setData('name', event.target.value)
                            }
                            aria-invalid={form.errors.name ? true : undefined}
                        />
                    </div>
                    <div className="grid gap-1.5">
                        <Label htmlFor="new-category-description">
                            {t('manage.category_description')}
                        </Label>
                        <Input
                            id="new-category-description"
                            value={form.data.description}
                            maxLength={300}
                            disabled={order.length >= max}
                            onChange={(event) =>
                                form.setData('description', event.target.value)
                            }
                        />
                    </div>
                    <Button
                        type="submit"
                        disabled={form.processing || order.length >= max}
                    >
                        <Plus className="size-4" aria-hidden />
                        {t('manage.add')}
                    </Button>
                    <div className="sm:col-span-3">
                        <InputError
                            message={
                                form.errors.name ?? form.errors.description
                            }
                        />
                    </div>
                </form>
            </FormSection>

            {order.length === 0 ? (
                <div className="rounded-2xl border border-dashed px-6 py-12 text-center text-sm text-muted-foreground">
                    {t('manage.no_categories')}
                </div>
            ) : (
                <ul
                    className="divide-y rounded-2xl border bg-card shadow-xs"
                    aria-label={t('manage.categories_title')}
                >
                    {order.map((category, index) => (
                        <CategoryRow
                            key={category.id}
                            category={category}
                            base={base}
                            first={index === 0}
                            last={index === order.length - 1}
                            busy={busy}
                            onMove={(direction) => move(index, direction)}
                        />
                    ))}
                </ul>
            )}
            <p className="text-xs text-muted-foreground">
                {t('manage.categories_note')}
            </p>
        </ManageLayout>
    );
}
