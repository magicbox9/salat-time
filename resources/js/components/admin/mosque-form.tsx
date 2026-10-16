import { Form } from '@inertiajs/react';
import { Save } from 'lucide-react';
import InputError from '@/components/input-error';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Spinner } from '@/components/ui/spinner';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import type { MosqueSummary } from '@/types/mosque';

type Props = {
    mosque: MosqueSummary;
    timezones: string[];
};

function Field({
    id,
    label,
    error,
    className,
    children,
}: {
    id: string;
    label: string;
    error?: string;
    className?: string;
    children: React.ReactNode;
}) {
    return (
        <div className={cn('grid gap-2', className)}>
            <Label htmlFor={id}>{label}</Label>
            {children}
            <InputError message={error} />
        </div>
    );
}

/** Corrects a mosque's name, address, position and time zone. */
export function MosqueForm({ mosque, timezones }: Props) {
    const t = useT();

    return (
        <Form
            action={`/admin/mosques/${mosque.slug}`}
            method="patch"
            options={{ preserveScroll: true }}
            setDefaultsOnSuccess
            className="grid gap-5 sm:grid-cols-2"
        >
            {({ errors, processing, isDirty }) => (
                <>
                    <Field
                        id="name"
                        label={t('admin.field_name')}
                        error={errors.name}
                        className="sm:col-span-2"
                    >
                        <Input
                            id="name"
                            name="name"
                            defaultValue={mosque.name}
                            required
                            maxLength={200}
                        />
                    </Field>
                    <Field
                        id="address"
                        label={t('admin.field_address')}
                        error={errors.address}
                        className="sm:col-span-2"
                    >
                        <Input
                            id="address"
                            name="address"
                            defaultValue={mosque.address ?? ''}
                            maxLength={300}
                        />
                    </Field>
                    <Field
                        id="postcode"
                        label={t('admin.field_postcode')}
                        error={errors.postcode}
                    >
                        <Input
                            id="postcode"
                            name="postcode"
                            defaultValue={mosque.postcode ?? ''}
                            maxLength={16}
                        />
                    </Field>
                    <Field
                        id="city"
                        label={t('admin.field_city')}
                        error={errors.city}
                    >
                        <Input
                            id="city"
                            name="city"
                            defaultValue={mosque.city ?? ''}
                            maxLength={120}
                        />
                    </Field>
                    <Field
                        id="latitude"
                        label={t('admin.field_latitude')}
                        error={errors.latitude}
                    >
                        <Input
                            id="latitude"
                            name="latitude"
                            type="number"
                            step="0.000001"
                            min={-90}
                            max={90}
                            required
                            dir="ltr"
                            className="text-start"
                            defaultValue={mosque.lat}
                        />
                    </Field>
                    <Field
                        id="longitude"
                        label={t('admin.field_longitude')}
                        error={errors.longitude}
                    >
                        <Input
                            id="longitude"
                            name="longitude"
                            type="number"
                            step="0.000001"
                            min={-180}
                            max={180}
                            required
                            dir="ltr"
                            className="text-start"
                            defaultValue={mosque.lng}
                        />
                    </Field>
                    <Field
                        id="timezone"
                        label={t('admin.field_timezone')}
                        error={errors.timezone}
                        className="sm:col-span-2"
                    >
                        <select
                            id="timezone"
                            name="timezone"
                            defaultValue={mosque.timezone}
                            dir="ltr"
                            className="h-9 w-full rounded-md border border-input bg-background px-3 text-start text-base shadow-xs outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 md:text-sm dark:bg-input/30"
                        >
                            {timezones.map((zone) => (
                                <option
                                    key={zone}
                                    value={zone}
                                    className="bg-background text-foreground"
                                >
                                    {zone}
                                </option>
                            ))}
                        </select>
                        <p className="text-xs text-muted-foreground">
                            {t('admin.field_timezone_hint')}
                        </p>
                    </Field>

                    <div className="flex items-center justify-end gap-3 border-t pt-5 sm:col-span-2">
                        {isDirty && (
                            <span className="text-xs text-muted-foreground">
                                {t('admin.unsaved')}
                            </span>
                        )}
                        <Button type="submit" disabled={processing}>
                            {processing ? <Spinner /> : <Save />}
                            {t('admin.save')}
                        </Button>
                    </div>
                </>
            )}
        </Form>
    );
}
