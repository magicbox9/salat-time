import {
    MonitorSmartphone,
    Palette,
    RectangleHorizontal,
    RectangleVertical,
    RotateCcw,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';
import { useT } from '@/lib/i18n';
import { PALETTES } from '../themes/palette';
import type { DisplayLanguage } from '../types';
import type { EditorProps } from './editor-types';
import { RangeRow, Section, Segmented, SelectRow, SwitchRow } from './controls';
import { ThemePicker } from './theme-picker';

/** Theme, orientation, colour, languages, clock and what the screen shows. */
export function AppearanceSection({
    value,
    onChange,
    errors,
    payload,
}: EditorProps) {
    const t = useT();
    const languageName = (code: DisplayLanguage) => t(`display.lang_${code}`);

    return (
        <Section
            id="appearance"
            title={t('display.section_appearance')}
            description={t('display.section_appearance_hint')}
            icon={Palette}
        >
            <ThemePicker value={value} onChange={onChange} payload={payload} />

            <Segmented
                label={t('display.orientation')}
                value={value.orientation}
                onChange={(orientation) => onChange({ orientation })}
                hint={t('display.orientation_hint')}
                options={[
                    {
                        value: 'auto',
                        label: t('display.orientation_auto'),
                        icon: MonitorSmartphone,
                    },
                    {
                        value: 'landscape',
                        label: t('display.orientation_landscape'),
                        icon: RectangleHorizontal,
                    },
                    {
                        value: 'portrait',
                        label: t('display.orientation_portrait'),
                        icon: RectangleVertical,
                    },
                ]}
            />

            <div className="grid content-start gap-1.5">
                <Label htmlFor="display-accent">{t('display.accent')}</Label>
                <div className="flex items-center gap-3">
                    <input
                        id="display-accent"
                        type="color"
                        value={
                            value.accent_color ?? PALETTES[value.theme].accent
                        }
                        onChange={(event) =>
                            onChange({
                                accent_color: event.target.value.toLowerCase(),
                            })
                        }
                        className="h-9 w-14 cursor-pointer rounded-md border border-input bg-transparent p-1"
                    />
                    {value.accent_color ? (
                        <span
                            className="font-mono text-sm text-muted-foreground"
                            dir="ltr"
                        >
                            {value.accent_color}
                        </span>
                    ) : (
                        <span className="text-sm text-muted-foreground">
                            {t('display.accent_theme')}
                        </span>
                    )}
                    {value.accent_color && (
                        <Button
                            type="button"
                            variant="ghost"
                            size="sm"
                            onClick={() => onChange({ accent_color: null })}
                        >
                            <RotateCcw className="size-4" />
                            {t('display.accent_reset')}
                        </Button>
                    )}
                </div>
                {errors.accent_color && (
                    <p className="text-sm text-destructive">
                        {errors.accent_color}
                    </p>
                )}
            </div>

            <div className="grid gap-5 sm:grid-cols-2">
                <SelectRow
                    label={t('display.language_main')}
                    value={value.languages[0]}
                    options={(['ar', 'fr', 'en'] as const).map((code) => ({
                        value: code,
                        label: languageName(code),
                    }))}
                    onChange={(code) => {
                        const main = code as DisplayLanguage;
                        const second =
                            value.languages[1] === main
                                ? undefined
                                : value.languages[1];
                        onChange({
                            languages: second ? [main, second] : [main],
                        });
                    }}
                    error={errors.languages}
                />
                <SelectRow
                    label={t('display.language_second')}
                    value={value.languages[1] ?? ''}
                    options={[
                        { value: '', label: t('display.language_none') },
                        ...(['ar', 'fr', 'en'] as const)
                            .filter((code) => code !== value.languages[0])
                            .map((code) => ({
                                value: code,
                                label: languageName(code),
                            })),
                    ]}
                    onChange={(code) =>
                        onChange({
                            languages: code
                                ? [value.languages[0], code as DisplayLanguage]
                                : [value.languages[0]],
                        })
                    }
                    hint={t('display.language_hint')}
                />
            </div>

            <Segmented
                label={t('display.clock')}
                value={value.clock}
                onChange={(clock) => onChange({ clock })}
                options={[
                    { value: '24h', label: t('display.clock_24h') },
                    { value: '12h', label: t('display.clock_12h') },
                ]}
            />

            <div className="grid gap-4">
                <SwitchRow
                    label={t('display.show_seconds')}
                    checked={value.show_seconds}
                    onChange={(show_seconds) => onChange({ show_seconds })}
                />
                <SwitchRow
                    label={t('display.show_iqama')}
                    checked={value.show_iqama}
                    onChange={(show_iqama) => onChange({ show_iqama })}
                />
                <SwitchRow
                    label={t('display.show_shuruq')}
                    checked={value.show_shuruq}
                    onChange={(show_shuruq) => onChange({ show_shuruq })}
                />
                <SwitchRow
                    label={t('display.show_jumua')}
                    checked={value.show_jumua}
                    onChange={(show_jumua) => onChange({ show_jumua })}
                />
                <SwitchRow
                    label={t('display.show_hijri')}
                    checked={value.show_hijri}
                    onChange={(show_hijri) => onChange({ show_hijri })}
                />
            </div>
            {value.show_hijri && (
                <RangeRow
                    label={t('display.hijri_adjust')}
                    hint={t('display.hijri_adjust_hint')}
                    value={value.hijri_adjust}
                    min={-2}
                    max={2}
                    unit={t('display.unit_days')}
                    onChange={(hijri_adjust) => onChange({ hijri_adjust })}
                    error={errors.hijri_adjust}
                />
            )}
        </Section>
    );
}
