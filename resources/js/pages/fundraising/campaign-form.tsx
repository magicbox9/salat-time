import { Link, useForm } from '@inertiajs/react';
import { CreditCard, Landmark, Lock } from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import InputError from '@/components/input-error';
import { KindPicker } from '@/components/fundraising/kind-picker';
import { FundraisingNav } from '@/components/fundraising/manage-nav';
import { ProblemsNotice } from '@/components/fundraising/problems-notice';
import type {
    AvailableMethods,
    CampaignKind,
    CampaignStatus,
    EligibilityProblem,
} from '@/components/fundraising/types';
import { Field, FormSection, Textarea } from '@/components/manage/fields';
import { ImageField } from '@/components/manage/image-field';
import { ManageLayout } from '@/components/manage/manage-layout';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Spinner } from '@/components/ui/spinner';
import { useT } from '@/lib/i18n';
import type { MosqueSummary } from '@/types/mosque';

type EditableCampaign = {
    slug: string;
    status: CampaignStatus;
    kind: CampaignKind;
    title: string;
    summary: string;
    story: string;
    cover_url: string | null;
    goal: number;
    starts_on: string;
    ends_on: string;
    allow_paypal: boolean;
    allow_bank: boolean;
    show_donor_names: boolean;
    locked: boolean;
};

type Props = {
    mosque: MosqueSummary;
    campaign: EditableCampaign | null;
    kinds: CampaignKind[];
    allowable: AvailableMethods;
    paypalEnabled: boolean;
    problems: EligibilityProblem[];
};

/** Writing or editing a campaign. Saved as a draft; it goes to review from its page. */
export default function CampaignForm({
    mosque,
    campaign,
    kinds,
    allowable,
    paypalEnabled,
    problems,
}: Props) {
    const t = useT();
    const editing = campaign !== null;
    const locked = campaign?.locked ?? false;
    const form = useForm({
        kind: campaign?.kind ?? ('building' as CampaignKind),
        title: campaign?.title ?? '',
        summary: campaign?.summary ?? '',
        story: campaign?.story ?? '',
        goal: campaign ? String(campaign.goal) : '',
        starts_on: campaign?.starts_on ?? '',
        ends_on: campaign?.ends_on ?? '',
        allow_paypal: campaign?.allow_paypal ?? allowable.paypal,
        allow_bank: campaign?.allow_bank ?? allowable.bank,
        show_donor_names: campaign?.show_donor_names ?? true,
        cover: null as File | null,
        remove_cover: false,
    });
    const { data, setData, errors, processing } = form;
    const base = `/manage/${mosque.slug}/campaigns`;

    const submit = (event: React.FormEvent) => {
        event.preventDefault();
        form.transform((current) => ({
            ...current,
            // A way of giving whose account is no longer verified shows
            // unticked and disabled: send it as it shows.
            allow_paypal: current.allow_paypal && allowable.paypal,
            allow_bank: current.allow_bank && allowable.bank,
            ...(editing ? { _method: 'put' } : {}),
        }));
        form.post(editing ? `${base}/${campaign.slug}` : base, {
            forceFormData: true,
            preserveScroll: true,
        });
    };

    const methods: {
        key: 'allow_paypal' | 'allow_bank';
        icon: LucideIcon;
        allowed: boolean;
    }[] = [
        { key: 'allow_paypal', icon: CreditCard, allowed: allowable.paypal },
        { key: 'allow_bank', icon: Landmark, allowed: allowable.bank },
    ];

    return (
        <ManageLayout
            mosque={mosque}
            title={
                editing
                    ? t('fundraising.edit_campaign')
                    : t('fundraising.new_campaign')
            }
        >
            <FundraisingNav mosqueSlug={mosque.slug} />
            <ProblemsNotice
                problems={problems}
                mosqueSlug={mosque.slug}
                title={t('fundraising.problems_draft_title')}
            />

            <form onSubmit={submit} className="space-y-6">
                <FormSection
                    title={t('fundraising.field_kind')}
                    description={
                        locked ? t('fundraising.locked_hint') : undefined
                    }
                >
                    <KindPicker
                        kinds={kinds}
                        value={data.kind}
                        onChange={(kind) => setData('kind', kind)}
                        disabled={locked}
                    />
                    <InputError message={errors.kind} />
                </FormSection>

                <FormSection title={t('fundraising.section_story')}>
                    <Field
                        id="title"
                        label={t('fundraising.field_title')}
                        error={errors.title}
                    >
                        <Input
                            id="title"
                            value={data.title}
                            maxLength={160}
                            required
                            disabled={locked}
                            onChange={(event) =>
                                setData('title', event.target.value)
                            }
                            aria-invalid={errors.title ? true : undefined}
                        />
                    </Field>
                    <Field
                        id="summary"
                        label={t('fundraising.field_summary')}
                        hint={t('fundraising.summary_hint')}
                        error={errors.summary}
                    >
                        <Textarea
                            id="summary"
                            rows={2}
                            maxLength={300}
                            required
                            value={data.summary}
                            onChange={(event) =>
                                setData('summary', event.target.value)
                            }
                            aria-invalid={errors.summary ? true : undefined}
                        />
                    </Field>
                    <Field
                        id="story"
                        label={t('fundraising.field_story')}
                        hint={t('fundraising.story_hint')}
                        error={errors.story}
                    >
                        <Textarea
                            id="story"
                            rows={12}
                            maxLength={20000}
                            required
                            value={data.story}
                            onChange={(event) =>
                                setData('story', event.target.value)
                            }
                            aria-invalid={errors.story ? true : undefined}
                        />
                        <span
                            className="text-end text-xs text-muted-foreground tabular-nums"
                            dir="ltr"
                        >
                            {data.story.length}/20000
                        </span>
                    </Field>
                    <ImageField
                        label={t('fundraising.field_cover')}
                        hint={t('fundraising.cover_hint')}
                        currentUrl={campaign?.cover_url ?? null}
                        file={data.cover}
                        removed={data.remove_cover}
                        onFile={(file) => setData('cover', file)}
                        onRemove={(removed) => setData('remove_cover', removed)}
                        error={errors.cover}
                    />
                </FormSection>

                <FormSection title={t('fundraising.section_goal')}>
                    <Field
                        id="goal"
                        label={t('fundraising.field_goal')}
                        hint={t('fundraising.goal_hint')}
                        error={errors.goal}
                    >
                        <div className="relative sm:w-56">
                            <Input
                                id="goal"
                                inputMode="numeric"
                                dir="ltr"
                                required
                                value={data.goal}
                                onChange={(event) =>
                                    setData(
                                        'goal',
                                        event.target.value
                                            .replace(/[^\d]/g, '')
                                            .slice(0, 8),
                                    )
                                }
                                className="pe-8"
                                aria-invalid={errors.goal ? true : undefined}
                            />
                            <span
                                className="pointer-events-none absolute end-3 top-1/2 -translate-y-1/2 text-muted-foreground"
                                aria-hidden
                            >
                                €
                            </span>
                        </div>
                    </Field>
                    <div className="grid gap-4 sm:grid-cols-2">
                        <Field
                            id="starts_on"
                            label={t('fundraising.field_starts_on')}
                            hint={t('fundraising.starts_hint')}
                            error={errors.starts_on}
                        >
                            <Input
                                id="starts_on"
                                type="date"
                                dir="ltr"
                                value={data.starts_on}
                                onChange={(event) =>
                                    setData('starts_on', event.target.value)
                                }
                            />
                        </Field>
                        <Field
                            id="ends_on"
                            label={t('fundraising.field_ends_on')}
                            hint={t('fundraising.ends_hint', {
                                timezone: mosque.timezone,
                            })}
                            error={errors.ends_on}
                        >
                            <Input
                                id="ends_on"
                                type="date"
                                dir="ltr"
                                value={data.ends_on}
                                onChange={(event) =>
                                    setData('ends_on', event.target.value)
                                }
                            />
                        </Field>
                    </div>
                </FormSection>

                <FormSection
                    title={t('fundraising.section_methods')}
                    description={t('fundraising.methods_hint')}
                >
                    {methods.map(({ key, icon: Icon, allowed }) => (
                        <div key={key} className="flex items-start gap-3">
                            <Checkbox
                                id={key}
                                checked={data[key] && allowed}
                                disabled={!allowed}
                                onCheckedChange={(checked) =>
                                    setData(key, checked === true)
                                }
                            />
                            <div className="grid gap-0.5">
                                <Label
                                    htmlFor={key}
                                    className="flex items-center gap-2 font-normal"
                                >
                                    <Icon
                                        className="size-4 text-muted-foreground"
                                        aria-hidden
                                    />
                                    {t(`fundraising.${key}`)}
                                </Label>
                                {!allowed && (
                                    <p className="flex items-center gap-1 text-xs text-muted-foreground">
                                        <Lock className="size-3" aria-hidden />
                                        {t(
                                            'fundraising.method_needs_verification',
                                        )}
                                    </p>
                                )}
                                {key === 'allow_paypal' &&
                                    allowed &&
                                    !paypalEnabled && (
                                        <p className="text-xs text-muted-foreground">
                                            {t(
                                                'fundraising.paypal_platform_off',
                                            )}
                                        </p>
                                    )}
                                <InputError message={errors[key]} />
                            </div>
                        </div>
                    ))}
                    <div className="flex items-start gap-3 border-t pt-4">
                        <Checkbox
                            id="show_donor_names"
                            checked={data.show_donor_names}
                            onCheckedChange={(checked) =>
                                setData('show_donor_names', checked === true)
                            }
                        />
                        <div className="grid gap-0.5">
                            <Label
                                htmlFor="show_donor_names"
                                className="font-normal"
                            >
                                {t('fundraising.show_donor_names')}
                            </Label>
                            <p className="text-xs text-muted-foreground">
                                {t('fundraising.show_donor_names_hint')}
                            </p>
                        </div>
                    </div>
                </FormSection>

                <div className="flex flex-col-reverse gap-2 sm:flex-row sm:items-center sm:justify-between">
                    <Button asChild variant="ghost">
                        <Link
                            href={editing ? `${base}/${campaign.slug}` : base}
                        >
                            {t('fundraising.cancel')}
                        </Link>
                    </Button>
                    <Button type="submit" disabled={processing}>
                        {processing && <Spinner />}
                        {editing
                            ? t('fundraising.save_changes')
                            : t('fundraising.save_draft')}
                    </Button>
                </div>
            </form>
        </ManageLayout>
    );
}
