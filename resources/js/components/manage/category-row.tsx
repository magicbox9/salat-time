import { useForm } from '@inertiajs/react';
import { ArrowDown, ArrowUp, Check, PencilLine, X } from 'lucide-react';
import { useState } from 'react';
import InputError from '@/components/input-error';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { useT } from '@/lib/i18n';
import { ConfirmDelete } from './confirm-delete';

export type ManagedCategory = {
    id: number;
    name: string;
    slug: string;
    description: string | null;
    posts_count: number;
};

type Props = {
    category: ManagedCategory;
    base: string;
    first: boolean;
    last: boolean;
    busy: boolean;
    onMove: (direction: -1 | 1) => void;
};

/** One category: rename in place, move up or down, delete (its posts stay, uncategorised). */
export function CategoryRow({
    category,
    base,
    first,
    last,
    busy,
    onMove,
}: Props) {
    const t = useT();
    const [editing, setEditing] = useState(false);
    const form = useForm({
        name: category.name,
        description: category.description ?? '',
    });

    const save = (event: React.FormEvent) => {
        event.preventDefault();
        form.put(`${base}/${category.id}`, {
            preserveScroll: true,
            onSuccess: () => setEditing(false),
        });
    };

    if (editing) {
        return (
            <li className="p-4">
                <form
                    onSubmit={save}
                    className="grid gap-3 sm:grid-cols-[1fr_1.4fr_auto] sm:items-start"
                >
                    <div className="grid gap-1">
                        <label
                            htmlFor={`cat-name-${category.id}`}
                            className="sr-only"
                        >
                            {t('manage.category_name')}
                        </label>
                        <Input
                            id={`cat-name-${category.id}`}
                            value={form.data.name}
                            maxLength={80}
                            required
                            autoFocus
                            onChange={(event) =>
                                form.setData('name', event.target.value)
                            }
                        />
                        <InputError message={form.errors.name} />
                    </div>
                    <div className="grid gap-1">
                        <label
                            htmlFor={`cat-desc-${category.id}`}
                            className="sr-only"
                        >
                            {t('manage.category_description')}
                        </label>
                        <Input
                            id={`cat-desc-${category.id}`}
                            value={form.data.description}
                            maxLength={300}
                            placeholder={t('manage.category_description')}
                            onChange={(event) =>
                                form.setData('description', event.target.value)
                            }
                        />
                        <InputError message={form.errors.description} />
                    </div>
                    <div className="flex gap-1">
                        <Button
                            type="submit"
                            size="sm"
                            disabled={form.processing}
                        >
                            <Check className="size-4" aria-hidden />
                            {t('manage.save')}
                        </Button>
                        <Button
                            type="button"
                            size="icon"
                            variant="ghost"
                            aria-label={t('manage.cancel')}
                            onClick={() => {
                                form.reset();
                                form.clearErrors();
                                setEditing(false);
                            }}
                        >
                            <X className="size-4" />
                        </Button>
                    </div>
                </form>
            </li>
        );
    }

    return (
        <li className="flex items-center gap-3 p-4">
            <div className="flex flex-col">
                <Button
                    variant="ghost"
                    size="icon"
                    className="size-7"
                    disabled={first || busy}
                    onClick={() => onMove(-1)}
                    aria-label={t('manage.move_up', { name: category.name })}
                >
                    <ArrowUp className="size-4" />
                </Button>
                <Button
                    variant="ghost"
                    size="icon"
                    className="size-7"
                    disabled={last || busy}
                    onClick={() => onMove(1)}
                    aria-label={t('manage.move_down', { name: category.name })}
                >
                    <ArrowDown className="size-4" />
                </Button>
            </div>
            <div className="min-w-0 flex-1">
                <p className="flex flex-wrap items-baseline gap-x-2 font-medium">
                    <span dir="auto">{category.name}</span>
                    <span
                        className="font-mono text-xs font-normal text-muted-foreground"
                        dir="ltr"
                    >
                        ?category={category.slug}
                    </span>
                </p>
                {category.description && (
                    <p
                        dir="auto"
                        className="truncate text-sm text-muted-foreground"
                    >
                        {category.description}
                    </p>
                )}
                <p className="text-xs text-muted-foreground">
                    {t('manage.category_posts', {
                        count: category.posts_count,
                    })}
                </p>
            </div>
            <div className="flex shrink-0 items-center gap-1">
                <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setEditing(true)}
                >
                    <PencilLine className="size-4" aria-hidden />
                    <span className="hidden sm:inline">
                        {t('manage.rename')}
                    </span>
                </Button>
                <ConfirmDelete
                    url={`${base}/${category.id}`}
                    title={t('manage.delete_category_title')}
                    description={t('manage.delete_category_body', {
                        name: category.name,
                        count: category.posts_count,
                    })}
                    iconOnly
                />
            </div>
        </li>
    );
}
