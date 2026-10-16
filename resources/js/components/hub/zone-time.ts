const formatters = new Map<string, Intl.DateTimeFormat>();

function formatter(timeZone: string): Intl.DateTimeFormat {
    let value = formatters.get(timeZone);

    if (!value) {
        value = new Intl.DateTimeFormat('en-US', {
            timeZone,
            hourCycle: 'h23',
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit',
        });
        formatters.set(timeZone, value);
    }

    return value;
}

/** How far the zone's wall clock is ahead of UTC at an instant (ms). */
function zoneOffset(timeZone: string, at: number): number {
    const parts = formatter(timeZone).formatToParts(new Date(at));
    const get = (type: string) =>
        Number(parts.find((part) => part.type === type)?.value ?? 0);
    const wall = Date.UTC(
        get('year'),
        get('month') - 1,
        get('day'),
        get('hour') % 24,
        get('minute'),
        get('second'),
    );

    return wall - Math.floor(at / 1000) * 1000;
}

/**
 * The instant (ms) at which the zone's wall clock reads `minutes` after the
 * midnight that starts `date` ("Y-m-d"); 1440 and more run into the next
 * days. Counting to it gives true countdowns across a DST change, where
 * wall-clock minutes are an hour off. Null when the zone is unknown.
 */
export function instantAt(
    date: string,
    minutes: number,
    timeZone: string,
): number | null {
    const [y, m, d] = date.split('-').map(Number);
    const wall = Date.UTC(y, m - 1, d) + Math.round(minutes * 60_000);

    if (Number.isNaN(wall)) {
        return null;
    }

    try {
        const first = wall - zoneOffset(timeZone, wall);

        return wall - zoneOffset(timeZone, first);
    } catch {
        return null;
    }
}
