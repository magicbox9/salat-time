import {
    BookOpen,
    HandCoins,
    Megaphone,
    Newspaper,
    Repeat,
    Sparkles,
} from 'lucide-react';
import { useT } from '@/lib/i18n';
import type { RotationSource } from '../types';
import type { EditorProps } from './editor-types';
import { RangeRow, Section, SwitchRow } from './controls';

const ICONS: Record<RotationSource, React.ElementType> = {
    messages: Megaphone,
    quran: BookOpen,
    adhkar: Sparkles,
    posts: Newspaper,
    campaigns: HandCoins,
};

/** What the rotating panel shows, and how long each slide stays. */
export function RotationSection({
    value,
    onChange,
    options,
    errors,
}: EditorProps) {
    const t = useT();
    const toggle = (source: RotationSource, on: boolean) => {
        // Keep the configured order of the sources.
        const next = options.rotation_sources.filter((s) =>
            s === source ? on : value.rotation.includes(s),
        );
        onChange({ rotation: next });
    };

    return (
        <Section
            id="rotation"
            title={t('display.section_rotation')}
            description={t('display.section_rotation_hint')}
            icon={Repeat}
        >
            <div className="grid gap-4">
                {options.rotation_sources.map((source) => {
                    const Icon = ICONS[source];

                    return (
                        <div key={source} className="flex items-start gap-3">
                            <Icon
                                className="mt-0.5 size-4 shrink-0 text-muted-foreground"
                                aria-hidden
                            />
                            <div className="min-w-0 flex-1">
                                <SwitchRow
                                    label={t(`display.source_${source}`)}
                                    hint={t(`display.source_${source}_hint`)}
                                    checked={value.rotation.includes(source)}
                                    onChange={(on) => toggle(source, on)}
                                />
                            </div>
                        </div>
                    );
                })}
            </div>
            <RangeRow
                label={t('display.rotation_seconds')}
                value={value.rotation_seconds}
                min={options.ranges.rotation_seconds[0]}
                max={options.ranges.rotation_seconds[1]}
                unit={t('display.unit_seconds')}
                onChange={(rotation_seconds) => onChange({ rotation_seconds })}
                error={errors.rotation_seconds ?? errors.rotation}
            />
        </Section>
    );
}
