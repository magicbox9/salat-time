/** Sky colours and stars for the Day path (pure helpers, no React). */

type Minutes = Record<
    'fajr' | 'shuruq' | 'dhuhr' | 'asr' | 'maghrib' | 'isha',
    number
>;

const NIGHT = 'oklch(0.22 0.05 262)';

/** Horizontal gradient stops: night, dawn, sunrise, day, golden hour, dusk, night. */
export function skyStops(
    m: Minutes,
    start: number,
    end: number,
    rtl: boolean,
): { offset: number; color: string }[] {
    const at = (minute: number) => {
        const f = Math.min(1, Math.max(0, (minute - start) / (end - start)));

        return rtl ? 1 - f : f;
    };
    const stops = [
        { minute: start, color: NIGHT },
        { minute: m.fajr, color: 'oklch(0.33 0.07 280)' },
        { minute: m.shuruq - 15, color: 'oklch(0.6 0.1 30)' },
        { minute: m.shuruq + 20, color: 'oklch(0.8 0.09 70)' },
        { minute: m.shuruq + 80, color: 'oklch(0.76 0.08 230)' },
        { minute: m.dhuhr, color: 'oklch(0.74 0.09 235)' },
        { minute: m.asr, color: 'oklch(0.76 0.08 225)' },
        { minute: m.maghrib - 50, color: 'oklch(0.78 0.1 70)' },
        { minute: m.maghrib, color: 'oklch(0.58 0.13 30)' },
        { minute: m.maghrib + 30, color: 'oklch(0.36 0.08 300)' },
        { minute: m.isha, color: 'oklch(0.26 0.06 270)' },
        { minute: end, color: NIGHT },
    ].map((stop) => ({
        offset: Number(at(stop.minute).toFixed(4)),
        color: stop.color,
    }));

    const sorted = rtl ? stops.reverse() : stops;
    let last = -1;

    // Offsets must never go backwards (very short nights squeeze the stops).
    return sorted.map((stop) => {
        last = Math.max(last, stop.offset);

        return { offset: last, color: stop.color };
    });
}

/** A fixed scatter of stars, kept only where `visible(x)` says the sky is dark. */
export function stars(
    width: number,
    height: number,
    visible: (x: number) => boolean,
): { x: number; y: number; r: number; delay: number }[] {
    let seed = 7;
    const random = () => {
        seed = (seed * 16807) % 2147483647;

        return (seed - 1) / 2147483646;
    };
    const out: { x: number; y: number; r: number; delay: number }[] = [];
    const count = Math.round(width / 9);

    for (let i = 0; i < count; i++) {
        const x = random() * width;
        const y = 6 + random() * (height - 26);
        const r = 0.5 + random() * 1.1;
        const delay = random() * 3.6;

        if (visible(x)) {
            out.push({ x, y, r, delay });
        }
    }

    return out;
}
