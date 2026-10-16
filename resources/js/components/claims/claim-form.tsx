import { Form } from '@inertiajs/react';
import { LockKeyhole, Send } from 'lucide-react';
import { useState } from 'react';
import InputError from '@/components/input-error';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Spinner } from '@/components/ui/spinner';
import { useT } from '@/lib/i18n';
import { DocumentField } from './document-field';
import { Textarea } from './textarea';

const MESSAGE_MAX = 2000;

/** The request form: role, optional phone, message and supporting document. */
export function ClaimForm({
    slug,
    documentMaxMb,
}: {
    slug: string;
    documentMaxMb: number;
}) {
    const t = useT();
    const [messageLength, setMessageLength] = useState(0);

    return (
        <Form
            action={`/mosques/${slug}/claim`}
            method="post"
            options={{ preserveScroll: true }}
            className="space-y-5"
        >
            {({ errors, processing, progress }) => (
                <>
                    <div className="grid gap-2">
                        <Label htmlFor="role_at_mosque">
                            {t('claims.field_role')}
                        </Label>
                        <Input
                            id="role_at_mosque"
                            name="role_at_mosque"
                            required
                            maxLength={120}
                            autoComplete="organization-title"
                            placeholder={t('claims.field_role_placeholder')}
                            aria-invalid={
                                errors.role_at_mosque ? true : undefined
                            }
                        />
                        <InputError message={errors.role_at_mosque} />
                    </div>

                    <div className="grid gap-2">
                        <Label htmlFor="phone">
                            {t('claims.field_phone')}{' '}
                            <span className="font-normal text-muted-foreground">
                                ({t('claims.optional')})
                            </span>
                        </Label>
                        <Input
                            id="phone"
                            name="phone"
                            type="tel"
                            dir="ltr"
                            maxLength={40}
                            autoComplete="tel"
                            inputMode="tel"
                            className="text-start"
                            placeholder="+33 6 12 34 56 78"
                            aria-describedby="phone-hint"
                            aria-invalid={errors.phone ? true : undefined}
                        />
                        <p
                            id="phone-hint"
                            className="text-xs text-muted-foreground"
                        >
                            {t('claims.field_phone_hint')}
                        </p>
                        <InputError message={errors.phone} />
                    </div>

                    <div className="grid gap-2">
                        <Label htmlFor="message">
                            {t('claims.field_message')}{' '}
                            <span className="font-normal text-muted-foreground">
                                ({t('claims.optional')})
                            </span>
                        </Label>
                        <Textarea
                            id="message"
                            name="message"
                            rows={5}
                            maxLength={MESSAGE_MAX}
                            placeholder={t('claims.field_message_placeholder')}
                            onChange={(event) =>
                                setMessageLength(event.target.value.length)
                            }
                            aria-invalid={errors.message ? true : undefined}
                        />
                        <div className="flex justify-between gap-3">
                            <InputError message={errors.message} />
                            <span
                                className="ms-auto text-xs text-muted-foreground tabular-nums"
                                dir="ltr"
                            >
                                {messageLength}/{MESSAGE_MAX}
                            </span>
                        </div>
                    </div>

                    <DocumentField
                        name="document"
                        maxMb={documentMaxMb}
                        error={errors.document}
                    />

                    {progress && (
                        <div
                            className="h-1.5 overflow-hidden rounded-full bg-muted"
                            aria-hidden
                        >
                            <div
                                className="h-full bg-primary transition-[width]"
                                style={{
                                    width: `${progress.percentage ?? 0}%`,
                                }}
                            />
                        </div>
                    )}

                    <div className="flex flex-col gap-3 border-t pt-5 sm:flex-row sm:items-center sm:justify-between">
                        <p className="flex items-start gap-2 text-xs text-muted-foreground">
                            <LockKeyhole
                                className="mt-0.5 size-3.5 shrink-0"
                                aria-hidden
                            />
                            {t('claims.privacy_note')}
                        </p>
                        <Button
                            type="submit"
                            disabled={processing}
                            className="shrink-0"
                        >
                            {processing ? (
                                <Spinner />
                            ) : (
                                <Send className="rtl:-scale-x-100" />
                            )}
                            {t('claims.submit')}
                        </Button>
                    </div>
                </>
            )}
        </Form>
    );
}
