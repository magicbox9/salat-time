import { Timer } from 'lucide-react';
import { useT } from '@/lib/i18n';
import type { ScreenPrayer } from '../types';
import type { EditorProps } from './editor-types';
import { RangeRow, Section, SwitchRow } from './controls';

/** How long each moment of a prayer lasts on screen. */
export function TimingSection({
    value,
    onChange,
    options,
    errors,
}: EditorProps) {
    const t = useT();
    const r = options.ranges;
    const minutes = t('display.unit_minutes');
    const setBlackout = (prayer: ScreenPrayer, amount: number) =>
        onChange({
            blackout_minutes: { ...value.blackout_minutes, [prayer]: amount },
        });

    return (
        <Section
            id="timing"
            title={t('display.section_timing')}
            description={t('display.section_timing_hint')}
            icon={Timer}
        >
            <RangeRow
                label={t('display.approaching_minutes')}
                hint={t('display.approaching_minutes_hint')}
                value={value.approaching_minutes}
                min={r.approaching_minutes[0]}
                max={r.approaching_minutes[1]}
                unit={minutes}
                onChange={(approaching_minutes) =>
                    onChange({ approaching_minutes })
                }
                error={errors.approaching_minutes}
            />
            <RangeRow
                label={t('display.adhan_minutes')}
                hint={t('display.adhan_minutes_hint')}
                value={value.adhan_minutes}
                min={r.adhan_minutes[0]}
                max={r.adhan_minutes[1]}
                unit={minutes}
                onChange={(adhan_minutes) => onChange({ adhan_minutes })}
                error={errors.adhan_minutes}
            />
            <RangeRow
                label={t('display.iqama_seconds')}
                hint={t('display.iqama_seconds_hint')}
                value={value.iqama_seconds}
                min={r.iqama_seconds[0]}
                max={r.iqama_seconds[1]}
                step={5}
                unit={t('display.unit_seconds')}
                onChange={(iqama_seconds) => onChange({ iqama_seconds })}
                error={errors.iqama_seconds}
            />

            <fieldset className="grid gap-4 rounded-xl bg-muted/50 p-4">
                <legend className="sr-only">{t('display.blackout')}</legend>
                <div>
                    <p className="text-sm font-medium">
                        {t('display.blackout')}
                    </p>
                    <p className="text-xs text-muted-foreground">
                        {t('display.blackout_hint')}
                    </p>
                </div>
                <div className="grid gap-4 sm:grid-cols-2">
                    {options.prayers.map((prayer) => (
                        <RangeRow
                            key={prayer}
                            label={t(`site.prayer_${prayer}`)}
                            value={value.blackout_minutes[prayer]}
                            min={r.blackout_minutes[0]}
                            max={r.blackout_minutes[1]}
                            unit={minutes}
                            onChange={(amount) => setBlackout(prayer, amount)}
                            error={errors[`blackout_minutes.${prayer}`]}
                        />
                    ))}
                </div>
            </fieldset>

            <SwitchRow
                label={t('display.after_adhkar')}
                hint={t('display.after_adhkar_hint')}
                checked={value.after_adhkar}
                onChange={(after_adhkar) => onChange({ after_adhkar })}
            />
            {value.after_adhkar && (
                <RangeRow
                    label={t('display.after_adhkar_minutes')}
                    value={value.after_adhkar_minutes}
                    min={r.after_adhkar_minutes[0]}
                    max={r.after_adhkar_minutes[1]}
                    unit={minutes}
                    onChange={(after_adhkar_minutes) =>
                        onChange({ after_adhkar_minutes })
                    }
                    error={errors.after_adhkar_minutes}
                />
            )}
        </Section>
    );
}
