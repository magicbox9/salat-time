import { useForm } from '@inertiajs/react';
import { Info } from 'lucide-react';
import { AccentColorField } from '@/components/manage/accent-color-field';
import { Field, FormSection, Textarea } from '@/components/manage/fields';
import { ImageField } from '@/components/manage/image-field';
import { ManageLayout } from '@/components/manage/manage-layout';
import { SocialLinksFields } from '@/components/manage/social-links-fields';
import type { SocialNetwork } from '@/components/mosque/site-types';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Spinner } from '@/components/ui/spinner';
import { useT } from '@/lib/i18n';
import type { MosqueSummary } from '@/types/mosque';

type Values = {
    tagline: string;
    accent_color: string;
    social_links: Record<string, string>;
    description: string;
    association: string;
    website: string;
    phone: string;
    email: string;
    jumua: string;
    jumua2: string;
    jumua3: string;
    jumua_as_dhuhr: boolean;
};

type TextField =
    | 'tagline'
    | 'association'
    | 'website'
    | 'phone'
    | 'email'
    | 'jumua'
    | 'jumua2'
    | 'jumua3';

type Props = {
    mosque: MosqueSummary & { cover_url: string | null };
    values: Values;
    palette: string[];
    networks: SocialNetwork[];
};

/** The details and look of the mosque's site. */
export default function ManageEdit({
    mosque,
    values,
    palette,
    networks,
}: Props) {
    const t = useT();
    const form = useForm({
        ...values,
        logo: null as File | null,
        cover: null as File | null,
        remove_logo: false,
        remove_cover: false,
    });
    const { data, setData, errors, processing } = form;
    const fieldErrors = errors as Record<string, string | undefined>;

    const submit = (event: React.FormEvent) => {
        event.preventDefault();
        form.transform((current) => ({ ...current, _method: 'put' }));
        form.post(`/manage/${mosque.slug}`, {
            forceFormData: true,
            preserveScroll: true,
            onSuccess: () =>
                form.setData((current) => ({
                    ...current,
                    logo: null,
                    cover: null,
                    remove_logo: false,
                    remove_cover: false,
                })),
        });
    };

    const text = (
        name: TextField,
        label: string,
        props: React.ComponentProps<typeof Input> = {},
        hint?: string,
    ) => (
        <Field id={name} label={label} hint={hint} error={errors[name]}>
            <Input
                id={name}
                value={String(data[name] ?? '')}
                onChange={(event) => setData(name, event.target.value)}
                aria-invalid={errors[name] ? true : undefined}
                {...props}
            />
        </Field>
    );

    return (
        <ManageLayout
            mosque={mosque}
            title={t('manage.details_title')}
            description={t('manage.details_intro')}
        >
            <form onSubmit={submit} className="space-y-6">
                <FormSection
                    title={t('manage.section_identity')}
                    description={t('manage.section_identity_hint')}
                >
                    <ImageField
                        label={t('manage.logo')}
                        hint={t('manage.logo_hint')}
                        shape="square"
                        currentUrl={mosque.logo_url}
                        file={data.logo}
                        removed={data.remove_logo}
                        onFile={(file) => setData('logo', file)}
                        onRemove={(removed) => setData('remove_logo', removed)}
                        error={errors.logo}
                    />
                    <ImageField
                        label={t('manage.cover')}
                        hint={t('manage.cover_hint')}
                        currentUrl={mosque.cover_url}
                        file={data.cover}
                        removed={data.remove_cover}
                        onFile={(file) => setData('cover', file)}
                        onRemove={(removed) => setData('remove_cover', removed)}
                        error={errors.cover}
                    />
                    {text(
                        'tagline',
                        t('manage.tagline'),
                        { maxLength: 200, dir: 'auto' },
                        t('manage.tagline_hint'),
                    )}
                    <AccentColorField
                        value={data.accent_color}
                        onChange={(value) => setData('accent_color', value)}
                        palette={palette}
                        error={errors.accent_color}
                    />
                </FormSection>

                <FormSection title={t('manage.section_about')}>
                    <Field
                        id="description"
                        label={t('manage.description')}
                        hint={t('manage.description_hint')}
                        error={errors.description}
                    >
                        <Textarea
                            id="description"
                            rows={6}
                            maxLength={5000}
                            dir="auto"
                            value={data.description}
                            onChange={(event) =>
                                setData('description', event.target.value)
                            }
                        />
                    </Field>
                    {text('association', t('manage.association'), {
                        maxLength: 200,
                    })}
                </FormSection>

                <FormSection title={t('manage.section_contact')}>
                    <div className="grid gap-5 sm:grid-cols-2">
                        {text('website', t('manage.website'), {
                            type: 'url',
                            placeholder: 'https://',
                            dir: 'ltr',
                            maxLength: 300,
                        })}
                        {text('phone', t('manage.phone'), {
                            type: 'tel',
                            dir: 'ltr',
                            maxLength: 40,
                        })}
                    </div>
                    {text('email', t('manage.email'), {
                        type: 'email',
                        dir: 'ltr',
                        maxLength: 200,
                    })}
                </FormSection>

                <FormSection
                    title={t('manage.section_social')}
                    description={t('manage.section_social_hint')}
                >
                    <SocialLinksFields
                        networks={networks}
                        values={data.social_links}
                        errors={fieldErrors}
                        onChange={(network, value) =>
                            setData('social_links', {
                                ...data.social_links,
                                [network]: value,
                            })
                        }
                    />
                </FormSection>

                <FormSection
                    title={t('site.prayer_jumua')}
                    description={t('manage.jumua_intro')}
                >
                    <div className="grid gap-5 sm:grid-cols-3">
                        {text('jumua', t('manage.jumua_n', { n: 1 }), {
                            type: 'time',
                            dir: 'ltr',
                        })}
                        {text('jumua2', t('manage.jumua_n', { n: 2 }), {
                            type: 'time',
                            dir: 'ltr',
                        })}
                        {text('jumua3', t('manage.jumua_n', { n: 3 }), {
                            type: 'time',
                            dir: 'ltr',
                        })}
                    </div>
                    <div className="flex items-center gap-2">
                        <Checkbox
                            id="jumua_as_dhuhr"
                            checked={data.jumua_as_dhuhr}
                            onCheckedChange={(checked) =>
                                setData('jumua_as_dhuhr', checked === true)
                            }
                        />
                        <Label htmlFor="jumua_as_dhuhr" className="font-normal">
                            {t('manage.jumua_as_dhuhr')}
                        </Label>
                    </div>
                </FormSection>

                <p className="flex items-start gap-2 rounded-xl bg-muted px-4 py-3 text-sm text-muted-foreground">
                    <Info className="mt-0.5 size-4 shrink-0" aria-hidden />
                    {t('manage.admin_fields_note')}
                </p>

                <div className="sticky bottom-4 z-10 flex items-center justify-end gap-3 rounded-2xl border bg-background/90 p-3 shadow-lg backdrop-blur">
                    {form.recentlySuccessful && (
                        <span className="text-sm text-muted-foreground">
                            {t('manage.saved')}
                        </span>
                    )}
                    <Button type="submit" disabled={processing}>
                        {processing && <Spinner />}
                        {t('manage.save')}
                    </Button>
                </div>
            </form>
        </ManageLayout>
    );
}
