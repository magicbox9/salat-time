import { useForm } from '@inertiajs/react';
import { Megaphone } from 'lucide-react';
import { Field, Textarea } from '@/components/manage/fields';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Spinner } from '@/components/ui/spinner';
import { useT } from '@/lib/i18n';

/** Posts a short piece of news on the campaign's page (Markdown). */
export function UpdateForm({ url }: { url: string }) {
    const t = useT();
    const form = useForm({ title: '', body: '' });

    return (
        <form
            onSubmit={(event) => {
                event.preventDefault();
                form.post(url, {
                    preserveScroll: true,
                    onSuccess: () => form.reset(),
                });
            }}
            className="grid gap-4 rounded-2xl border bg-muted/30 p-4"
        >
            <Field
                id="update_title"
                label={t('fundraising.field_update_title')}
                error={form.errors.title}
            >
                <Input
                    id="update_title"
                    maxLength={160}
                    required
                    value={form.data.title}
                    onChange={(event) =>
                        form.setData('title', event.target.value)
                    }
                />
            </Field>
            <Field
                id="update_body"
                label={t('fundraising.field_update_body')}
                hint={t('fundraising.story_hint')}
                error={form.errors.body}
            >
                <Textarea
                    id="update_body"
                    rows={4}
                    maxLength={10000}
                    required
                    value={form.data.body}
                    onChange={(event) =>
                        form.setData('body', event.target.value)
                    }
                />
            </Field>
            <Button
                type="submit"
                disabled={form.processing}
                className="justify-self-start"
            >
                {form.processing ? (
                    <Spinner />
                ) : (
                    <Megaphone className="size-4" aria-hidden />
                )}
                {t('fundraising.publish_update')}
            </Button>
        </form>
    );
}
