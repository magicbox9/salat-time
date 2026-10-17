import { Field, Textarea } from '@/components/manage/fields';
import { Checkbox } from '@/components/ui/checkbox';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { useT } from '@/lib/i18n';

export type DonorValues = {
    name: string;
    email: string;
    anonymous: boolean;
    message: string;
};

type Props = {
    values: DonorValues;
    onChange: (values: DonorValues) => void;
    errors: Record<string, string | undefined>;
    /** Signed-in donors: the account's name and email are already there. */
    signedIn: boolean;
};

/** Who gives: name and email (for the mosque and the receipt), anonymity, a word of support. */
export function DonorFields({ values, onChange, errors, signedIn }: Props) {
    const t = useT();
    const set = <K extends keyof DonorValues>(key: K, value: DonorValues[K]) =>
        onChange({ ...values, [key]: value });

    return (
        <div className="grid gap-4">
            <div className="grid gap-4 min-[420px]:grid-cols-2">
                <Field
                    id="donor_name"
                    label={t('fundraising.field_name')}
                    error={errors.donor_name}
                >
                    <Input
                        id="donor_name"
                        autoComplete="name"
                        maxLength={120}
                        value={values.name}
                        onChange={(event) => set('name', event.target.value)}
                        aria-invalid={errors.donor_name ? true : undefined}
                        required
                    />
                </Field>
                <Field
                    id="donor_email"
                    label={t('fundraising.field_email')}
                    error={errors.donor_email}
                    hint={signedIn ? undefined : t('fundraising.email_hint')}
                >
                    <Input
                        id="donor_email"
                        type="email"
                        autoComplete="email"
                        dir="ltr"
                        maxLength={200}
                        value={values.email}
                        onChange={(event) => set('email', event.target.value)}
                        aria-invalid={errors.donor_email ? true : undefined}
                        required
                    />
                </Field>
            </div>

            <Field
                id="donor_message"
                label={t('fundraising.field_message')}
                hint={t('fundraising.message_hint')}
                error={errors.message}
            >
                <Textarea
                    id="donor_message"
                    rows={2}
                    maxLength={500}
                    value={values.message}
                    onChange={(event) => set('message', event.target.value)}
                    className="min-h-16"
                />
            </Field>

            <div className="flex items-start gap-2.5">
                <Checkbox
                    id="donor_anonymous"
                    checked={values.anonymous}
                    onCheckedChange={(checked) =>
                        set('anonymous', checked === true)
                    }
                />
                <div className="grid gap-0.5">
                    <Label htmlFor="donor_anonymous" className="font-normal">
                        {t('fundraising.anonymous')}
                    </Label>
                    <p className="text-xs text-muted-foreground">
                        {t('fundraising.anonymous_hint')}
                    </p>
                </div>
            </div>
        </div>
    );
}
