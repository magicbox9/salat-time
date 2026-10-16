import { ChevronDown, HeartHandshake } from 'lucide-react';
import {
    Collapsible,
    CollapsibleContent,
    CollapsibleTrigger,
} from '@/components/ui/collapsible';
import { useT } from '@/lib/i18n';
import { HASANAT_TEXT } from './tracker-utils';
import type { HasanatRules as Rules } from './types';

/** How points are counted (config/hasanat.php), with the humble reminder. */
export function HasanatRules({ rules }: { rules: Rules }) {
    const t = useT();
    const rows: [string, string][] = [
        [t('prayers.status_on_time'), `+${rules.base.on_time}`],
        [t('prayers.status_late'), `+${rules.base.late}`],
        [t('prayers.status_qada'), `+${rules.base.qada}`],
        [t('prayers.status_missed'), '0'],
        [t('prayers.rule_mosque'), `+${rules.mosque}`],
        [t('prayers.rule_congregation'), `+${rules.congregation}`],
        [
            t('prayers.rule_congregation_fajr_isha'),
            `+${rules.congregation_fajr_isha}`,
        ],
        [
            t('prayers.rule_streak', { max: rules.streak_max_days }),
            `+${rules.streak_per_day}`,
        ],
        [t('prayers.rule_khushu'), `≤ +${rules.khushu_max}`],
        [t('prayers.rule_rakaat'), `+${rules.complete_rakaat}`],
    ];

    return (
        <section className="rounded-xl border border-gold/30 bg-gold/5 p-4 sm:p-5">
            <p className="flex gap-2.5 text-sm leading-relaxed">
                <HeartHandshake className="mt-0.5 size-4 shrink-0 text-amber-700 dark:text-gold" />
                <span>{t('prayers.humble_note')}</span>
            </p>
            <Collapsible className="mt-3">
                <CollapsibleTrigger className="group flex items-center gap-1 text-sm font-medium text-primary hover:underline">
                    {t('prayers.rules_title')}
                    <ChevronDown className="size-4 transition group-data-[state=open]:rotate-180" />
                </CollapsibleTrigger>
                <CollapsibleContent>
                    <dl className="mt-3 divide-y divide-gold/20 text-sm">
                        {rows.map(([label, value]) => (
                            <div
                                key={label}
                                className="flex items-center justify-between gap-3 py-1.5"
                            >
                                <dt className="text-muted-foreground">
                                    {label}
                                </dt>
                                <dd
                                    className={`font-medium tabular-nums ${HASANAT_TEXT}`}
                                    dir="ltr"
                                >
                                    {value}
                                </dd>
                            </div>
                        ))}
                    </dl>
                    <p className="mt-2 text-xs text-muted-foreground">
                        {t('prayers.rules_phone_note')}
                    </p>
                </CollapsibleContent>
            </Collapsible>
        </section>
    );
}
