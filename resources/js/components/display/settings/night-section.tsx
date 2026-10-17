import { MoonStar } from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { useT } from '@/lib/i18n';
import type { EditorProps } from './editor-types';
import { Section, SwitchRow } from './controls';

/** Dimming the screen at night (outside the prayers' own moments). */
export function NightSection({ value, onChange, errors }: EditorProps) {
    const t = useT();

    return (
        <Section
            id="night"
            title={t('display.section_night')}
            description={t('display.section_night_hint')}
            icon={MoonStar}
        >
            <SwitchRow
                label={t('display.night_dim')}
                checked={value.night_dim}
                onChange={(night_dim) => onChange({ night_dim })}
            />
            {value.night_dim && (
                <div className="grid gap-4 sm:grid-cols-2">
                    <div className="grid gap-1.5">
                        <Label htmlFor="night-from">
                            {t('display.night_from')}
                        </Label>
                        <Input
                            id="night-from"
                            type="time"
                            dir="ltr"
                            value={value.night_from}
                            onChange={(event) =>
                                event.target.value &&
                                onChange({
                                    night_from: event.target.value.slice(0, 5),
                                })
                            }
                        />
                        {errors.night_from && (
                            <p className="text-sm text-destructive">
                                {errors.night_from}
                            </p>
                        )}
                    </div>
                    <div className="grid gap-1.5">
                        <Label htmlFor="night-to">
                            {t('display.night_to')}
                        </Label>
                        <Input
                            id="night-to"
                            type="time"
                            dir="ltr"
                            value={value.night_to}
                            onChange={(event) =>
                                event.target.value &&
                                onChange({
                                    night_to: event.target.value.slice(0, 5),
                                })
                            }
                        />
                        {errors.night_to && (
                            <p className="text-sm text-destructive">
                                {errors.night_to}
                            </p>
                        )}
                    </div>
                </div>
            )}
        </Section>
    );
}
