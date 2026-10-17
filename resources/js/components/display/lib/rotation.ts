import type {
    Dhikr,
    DisplayPayload,
    DisplaySettings,
    RotationSource,
    ScreenCampaign,
    ScreenPost,
    Verse,
} from '../types';

export type Slide =
    | { kind: 'message'; key: string; body: string }
    | { kind: 'verse'; key: string; verse: Verse }
    | { kind: 'dhikr'; key: string; dhikr: Dhikr }
    | { kind: 'post'; key: string; post: ScreenPost }
    | { kind: 'campaign'; key: string; campaign: ScreenCampaign };

/** Each enabled source's slides, in the order the settings list them. */
export function slideLists(
    payload: DisplayPayload,
    settings: DisplaySettings,
    campaigns: ScreenCampaign[],
    period: 'morning' | 'evening',
    now: Date,
): Slide[][] {
    const lists: Record<RotationSource, Slide[]> = {
        messages: payload.messages
            .filter(
                (m) =>
                    !m.ends_at || new Date(m.ends_at).getTime() > now.getTime(),
            )
            .map((m) => ({ kind: 'message', key: `m${m.id}`, body: m.body })),
        quran: payload.rotation.verses.map((verse) => ({
            kind: 'verse',
            key: `q${verse.key}`,
            verse,
        })),
        adhkar: payload.rotation.adhkar
            .filter((d) => d.when.includes(period))
            .map((dhikr) => ({ kind: 'dhikr', key: `d${dhikr.id}`, dhikr })),
        posts: payload.rotation.posts.map((post) => ({
            kind: 'post',
            key: `p${post.id}`,
            post,
        })),
        campaigns: campaigns.map((campaign, i) => ({
            kind: 'campaign',
            key: `c${i}:${campaign.title}`,
            campaign,
        })),
    };

    return settings.rotation
        .map((source) => lists[source])
        .filter((list) => list.length > 0);
}

/**
 * The slide on screen at an instant. Sources take turns (a message, a verse,
 * a dhikr, …) and each moves on through its own list. Driven by the clock
 * alone, so screens of the same mosque stay in step and nothing is stored.
 */
export function slideAt(
    lists: Slide[][],
    nowMs: number,
    seconds: number,
): { slide: Slide; slot: number } | null {
    if (lists.length === 0) {
        return null;
    }

    const slot = Math.floor(nowMs / 1000 / Math.max(1, seconds));
    const list = lists[slot % lists.length];
    const round = Math.floor(slot / lists.length);

    return { slide: list[round % list.length], slot };
}

/** A font size (in cqmin) that shrinks as a text grows, within bounds. */
export function fitSize(
    text: string,
    base: number,
    comfortable: number,
    min = 0.42,
): number {
    const length = Math.max(1, text.length);

    return base * Math.max(min, Math.min(1, Math.sqrt(comfortable / length)));
}

/** The KFGQPC ayah-end glyph removed for display without the publisher font (never stored). */
export function withoutAyahMark(text: string): string {
    return text.replace(/[ﰀ-﷿]/g, '').replace(/^[\s ]+|[\s ]+$/g, '');
}

/** A font size in cqmin, scaled down by useFitText when the slide is too long for its box. */
export const fit = (cqmin: number) => ({
    fontSize: `calc(${cqmin.toFixed(2)}cqmin * var(--fit, 1))`,
});
