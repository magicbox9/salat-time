import {
    Bell,
    BellRing,
    Clock,
    Moon,
    RotateCcw,
    Sparkles,
    Users,
} from 'lucide-react';
import { useEffect, useState } from 'react';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { useTicker } from '../hooks/use-ticker';
import { parseCampaigns } from '../lib/campaigns';
import { buildModel } from '../lib/model';
import { DisplayScreen } from '../screen/display-screen';
import type {
    DisplayPayload,
    DisplaySettings,
    ScreenCampaign,
    SimulatedPhase,
    Simulation,
} from '../types';

const MOMENTS: { phase: SimulatedPhase; icon: React.ElementType }[] = [
    { phase: 'approaching', icon: Clock },
    { phase: 'adhan', icon: BellRing },
    { phase: 'iqama_countdown', icon: Bell },
    { phase: 'iqama', icon: Users },
    { phase: 'prayer', icon: Moon },
    { phase: 'after_adhkar', icon: Sparkles },
];

/**
 * The screen itself, live, with the settings not yet saved — scaled into a
 * 16:9 frame (9:16 when the screen is set to portrait). Buttons play a
 * prayer's moments on demand.
 */
export function PreviewFrame({
    payload,
    settings,
}: {
    payload: DisplayPayload;
    settings: DisplaySettings;
}) {
    const t = useT();
    const now = useTicker();
    const [simulation, setSimulation] = useState<Simulation | null>(null);
    const [campaigns, setCampaigns] = useState<ScreenCampaign[]>([]);
    const slug = payload.mosque.slug;
    const finished =
        simulation !== null &&
        now.getTime() - simulation.startedAt > 2000 &&
        buildModel(payload, settings, now, simulation).phase.kind === 'normal';

    useEffect(() => {
        if (finished) {
            setSimulation(null);
        }
    }, [finished]);

    useEffect(() => {
        const controller = new AbortController();
        fetch(`/mosques/${slug}/campaigns.json`, {
            headers: { Accept: 'application/json' },
            signal: controller.signal,
        })
            .then((response) => (response.ok ? response.json() : null))
            .then((body) => setCampaigns(parseCampaigns(body)))
            .catch(() => undefined);

        return () => controller.abort();
    }, [slug]);

    const portrait = settings.orientation === 'portrait';
    const hasTimes = buildModel(payload, settings, now).day !== null;

    return (
        <div className="space-y-3">
            <div
                className={cn(
                    'mx-auto overflow-hidden rounded-xl bg-black shadow-lg ring-1 ring-border',
                    portrait
                        ? 'aspect-[9/16] w-full max-w-[19rem]'
                        : 'aspect-video w-full',
                )}
                role="img"
                aria-label={t('display.preview_label')}
            >
                <DisplayScreen
                    payload={payload}
                    settings={settings}
                    campaigns={campaigns}
                    now={now}
                    preview
                    simulation={simulation}
                    className="size-full"
                />
            </div>
            <div className="space-y-2">
                <p className="text-xs font-medium text-muted-foreground">
                    {t('display.simulate')}
                </p>
                <div className="flex flex-wrap gap-1.5">
                    {MOMENTS.map(({ phase, icon: Icon }) => (
                        <Button
                            key={phase}
                            type="button"
                            size="sm"
                            variant={
                                simulation?.phase === phase
                                    ? 'default'
                                    : 'outline'
                            }
                            onClick={() =>
                                setSimulation({ phase, startedAt: Date.now() })
                            }
                            disabled={!hasTimes}
                        >
                            <Icon className="size-3.5" />
                            {t(`display.simulate_${phase}`)}
                        </Button>
                    ))}
                    {simulation && (
                        <Button
                            type="button"
                            size="sm"
                            variant="ghost"
                            onClick={() => setSimulation(null)}
                        >
                            <RotateCcw className="size-3.5" />
                            {t('display.simulate_stop')}
                        </Button>
                    )}
                </div>
            </div>
        </div>
    );
}
