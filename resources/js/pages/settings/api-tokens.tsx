import { Head, useForm, usePage } from '@inertiajs/react';
import { Check, Copy, ShieldAlert } from 'lucide-react';
import Heading from '@/components/heading';
import InputError from '@/components/input-error';
import type { ApiToken } from '@/components/prayers/api-token-list';
import { ApiTokenList } from '@/components/prayers/api-token-list';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { useClipboard } from '@/hooks/use-clipboard';
import { useT } from '@/lib/i18n';

type Props = {
    tokens: ApiToken[];
    maxTokens: number;
    lifetimeDays: number;
    apiBase: string;
};

type NewToken = { id: number; name: string; token: string };

/** Settings → Companion app: tokens for the iOS / Android apps. */
export default function ApiTokens({
    tokens,
    maxTokens,
    lifetimeDays,
    apiBase,
}: Props) {
    const t = useT();
    const page = usePage();
    const newToken = (page.flash as { newToken?: NewToken } | undefined)
        ?.newToken;
    const [copied, copy] = useClipboard();
    const form = useForm({ name: '' });

    const submit = (event: React.FormEvent) => {
        event.preventDefault();
        form.post('/settings/api-tokens', {
            preserveScroll: true,
            onSuccess: () => form.reset(),
        });
    };

    return (
        <>
            <Head title={t('prayers.tokens_title')} />
            <h1 className="sr-only">{t('prayers.tokens_title')}</h1>

            <div className="space-y-6">
                <Heading
                    variant="small"
                    title={t('prayers.tokens_title')}
                    description={t('prayers.tokens_intro')}
                />

                {newToken && (
                    <div className="space-y-3 rounded-xl border border-gold/50 bg-gold/10 p-4">
                        <p className="flex items-start gap-2 text-sm font-medium">
                            <ShieldAlert className="mt-0.5 size-4 shrink-0 text-amber-700 dark:text-gold" />
                            {t('prayers.tokens_new_once', {
                                name: newToken.name,
                            })}
                        </p>
                        <div className="flex items-center gap-2">
                            <code
                                className="min-w-0 flex-1 rounded-md border bg-background px-3 py-2 font-mono text-xs break-all select-all"
                                dir="ltr"
                            >
                                {newToken.token}
                            </code>
                            <Button
                                type="button"
                                variant="outline"
                                size="sm"
                                onClick={() => copy(newToken.token)}
                                aria-label={t('prayers.tokens_copy')}
                            >
                                {copied === newToken.token ? (
                                    <Check className="size-4" />
                                ) : (
                                    <Copy className="size-4" />
                                )}
                                {copied === newToken.token
                                    ? t('prayers.tokens_copied')
                                    : t('prayers.tokens_copy')}
                            </Button>
                        </div>
                    </div>
                )}

                <form onSubmit={submit} className="space-y-2">
                    <Label htmlFor="token-name">
                        {t('prayers.tokens_name_label')}
                    </Label>
                    <div className="flex flex-col gap-2 sm:flex-row">
                        <Input
                            id="token-name"
                            value={form.data.name}
                            onChange={(event) =>
                                form.setData('name', event.target.value)
                            }
                            placeholder={t('prayers.tokens_name_placeholder')}
                            maxLength={60}
                            required
                            className="flex-1"
                        />
                        <Button
                            type="submit"
                            disabled={
                                form.processing || tokens.length >= maxTokens
                            }
                        >
                            {t('prayers.tokens_create')}
                        </Button>
                    </div>
                    <InputError message={form.errors.name} />
                    <p className="text-xs text-muted-foreground">
                        {t('prayers.tokens_hint', {
                            days: lifetimeDays,
                            max: maxTokens,
                        })}
                    </p>
                </form>

                <ApiTokenList tokens={tokens} />

                <div className="space-y-2 rounded-xl border bg-muted/40 p-4 text-sm">
                    <p className="font-medium">
                        {t('prayers.tokens_how_title')}
                    </p>
                    <p className="text-muted-foreground">
                        {t('prayers.tokens_how_text')}
                    </p>
                    <pre
                        className="overflow-x-auto rounded-md border bg-background p-3 font-mono text-xs"
                        dir="ltr"
                    >
                        {`GET ${apiBase}/me\nAuthorization: Bearer <token>\nAccept: application/json`}
                    </pre>
                </div>
            </div>
        </>
    );
}
