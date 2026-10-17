import { dayMinutes } from '@/lib/prayer-time';
import type { DayTimes } from '@/types/mosque';
import type {
    DisplaySettings,
    ScreenPrayer,
    SimulatedPhase,
    Simulation,
} from '../types';
import { hhmm } from './zone';

/** One prayer of a day, on the clock of the day the screen shows (minutes). */
export type PrayerEvent = {
    prayer: ScreenPrayer;
    /** Published adhan time. */
    time: string;
    adhan: number;
    iqamaTime: string | null;
    iqama: number | null;
    /** Days from the day shown (-1 yesterday, 0 today, 1 tomorrow). */
    offset: number;
};

export type PhaseKind = 'normal' | SimulatedPhase;

export type Phase = {
    kind: PhaseKind;
    event: PrayerEvent | null;
    /** Minutes until the moment this phase leads to. */
    remaining: number;
    /** 0 → 1 through the phase. */
    progress: number;
};

export const NORMAL: Phase = {
    kind: 'normal',
    event: null,
    remaining: 0,
    progress: 0,
};

/** Longest believable gap between an adhan and its iqama. */
const MAX_IQAMA_GAP = 120;

/**
 * A published day as prayer events. On Friday, Dhuhr becomes Jumu'a at the
 * mosque's Jumu'a time (it has no published iqama: the khutbah follows the adhan).
 */
export function dayEvents(
    day: DayTimes,
    offset: number,
    isFriday: boolean,
): PrayerEvent[] {
    const minutes = dayMinutes(day);
    const shift = offset * 1440;
    const events: PrayerEvent[] = [];

    for (const prayer of ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'] as const) {
        const jumua =
            prayer === 'dhuhr' && isFriday && day.jumua
                ? hhmm(day.jumua)
                : null;

        if (jumua !== null && day.jumua) {
            events.push({
                prayer: 'jumua',
                time: day.jumua,
                adhan: jumua + shift,
                iqamaTime: null,
                iqama: null,
                offset,
            });
            continue;
        }

        const adhan = minutes[prayer];
        const iqamaTime = day.iqama[prayer] ?? null;
        let iqama = hhmm(iqamaTime);

        if (iqama !== null) {
            // An iqama after midnight follows an Isha after midnight.
            while (iqama < adhan) {
                iqama += 1440;
            }

            if (iqama - adhan > MAX_IQAMA_GAP) {
                iqama = null;
            }
        }

        events.push({
            prayer,
            time: day.times[prayer],
            adhan: adhan + shift,
            iqamaTime: iqama === null ? null : iqamaTime,
            iqama: iqama === null ? null : iqama + shift,
            offset,
        });
    }

    return events;
}

/**
 * Where the screen is in a prayer's cycle: approaching → adhan → iqama
 * countdown → iqama → prayer (dimmed) → after-prayer adhkar → normal.
 */
export function phaseAt(
    events: PrayerEvent[],
    now: number,
    s: DisplaySettings,
): Phase {
    for (const e of events) {
        const adhanEnd =
            s.adhan_mode === 'off' ? e.adhan : e.adhan + s.adhan_minutes;
        // Jumu'a: the khutbah begins after the adhan.
        const start = e.iqama ?? (e.prayer === 'jumua' ? adhanEnd : null);
        const phase = (kind: PhaseKind, from: number, to: number): Phase => ({
            kind,
            event: e,
            remaining: to - now,
            progress:
                to > from
                    ? Math.min(1, Math.max(0, (now - from) / (to - from)))
                    : 1,
        });

        if (
            s.approaching_minutes > 0 &&
            now >= e.adhan - s.approaching_minutes &&
            now < e.adhan
        ) {
            return phase(
                'approaching',
                e.adhan - s.approaching_minutes,
                e.adhan,
            );
        }

        if (now >= e.adhan && now < Math.min(adhanEnd, start ?? Infinity)) {
            return phase(
                'adhan',
                e.adhan,
                Math.min(adhanEnd, start ?? Infinity),
            );
        }

        if (start === null) {
            continue;
        }

        if (e.iqama !== null && now >= e.adhan && now < e.iqama) {
            return phase('iqama_countdown', e.adhan, e.iqama);
        }

        const flash = e.iqama !== null ? s.iqama_seconds / 60 : 0;

        if (now >= start && now < start + flash) {
            return phase('iqama', start, start + flash);
        }

        const prayerStart = start + flash;
        const blackout = s.blackout_minutes[e.prayer] ?? 0;

        if (now >= prayerStart && now < prayerStart + blackout) {
            return phase('prayer', prayerStart, prayerStart + blackout);
        }

        const adhkarStart = prayerStart + blackout;

        if (
            s.after_adhkar &&
            now >= adhkarStart &&
            now < adhkarStart + s.after_adhkar_minutes
        ) {
            return phase(
                'after_adhkar',
                adhkarStart,
                adhkarStart + s.after_adhkar_minutes,
            );
        }
    }

    return NORMAL;
}

/**
 * The preview's "simulate" buttons: a made-up prayer placed so that the
 * chosen phase starts at the moment of the click, then runs its course.
 */
export function simulate(
    sim: Simulation,
    nowMs: number,
    now: number,
    s: DisplaySettings,
    prayer: ScreenPrayer,
): { events: PrayerEvent[]; settings: DisplaySettings } {
    const t0 = now - (nowMs - sim.startedAt) / 60_000;
    const settings: DisplaySettings = {
        ...s,
        approaching_minutes: Math.max(1, s.approaching_minutes),
        adhan_mode: s.adhan_mode === 'off' ? 'visual' : s.adhan_mode,
        after_adhkar: sim.phase === 'after_adhkar' ? true : s.after_adhkar,
        blackout_minutes: {
            ...s.blackout_minutes,
            [prayer]: Math.max(1, s.blackout_minutes[prayer] ?? 0),
        },
    };
    const flash = settings.iqama_seconds / 60;
    const blackout = settings.blackout_minutes[prayer];
    const gap = settings.adhan_minutes + 2;
    const iqamaAt: Record<SimulatedPhase, number> = {
        approaching: t0 + settings.approaching_minutes + gap,
        adhan: t0 + gap,
        iqama_countdown: t0 + 2,
        iqama: t0,
        prayer: t0 - flash,
        after_adhkar: t0 - flash - blackout,
    };
    const iqama = iqamaAt[sim.phase];
    const adhan =
        sim.phase === 'iqama_countdown'
            ? t0 - settings.adhan_minutes
            : iqama - gap;
    const time = (m: number) => {
        const v = ((Math.floor(m) % 1440) + 1440) % 1440;

        return `${String(Math.floor(v / 60)).padStart(2, '0')}:${String(v % 60).padStart(2, '0')}`;
    };

    return {
        settings,
        events: [
            {
                prayer,
                time: time(adhan),
                adhan,
                iqamaTime: time(iqama),
                iqama,
                offset: 0,
            },
        ],
    };
}
