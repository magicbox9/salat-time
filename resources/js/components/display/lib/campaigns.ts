import type { ScreenCampaign } from '../types';

const amount = (value: unknown): number | null =>
    typeof value === 'number' && Number.isFinite(value) && value >= 0
        ? value
        : null;

/**
 * Campaigns from GET /mosques/{slug}/campaigns.json (module "fundraising"),
 * read loosely: a list, or { campaigns: [...] } / { data: [...] }. Amounts are
 * in cents, as stored (`raised_amount`, `goal_amount`). Anything unexpected
 * is skipped, so a missing or changed endpoint only hides the slide.
 */
export function parseCampaigns(body: unknown): ScreenCampaign[] {
    const record = body as Record<string, unknown> | null;
    const list = Array.isArray(body)
        ? body
        : Array.isArray(record?.campaigns)
          ? record.campaigns
          : Array.isArray(record?.data)
            ? record.data
            : [];

    return list.slice(0, 10).flatMap((item): ScreenCampaign[] => {
        if (!item || typeof item !== 'object') {
            return [];
        }

        const c = item as Record<string, unknown>;
        const title = typeof c.title === 'string' ? c.title.trim() : '';
        const raised =
            amount(c.raised_amount) ??
            amount(c.raised_cents) ??
            amount(c.raised);

        if (title === '' || raised === null) {
            return [];
        }

        const goal =
            amount(c.goal_amount) ?? amount(c.goal_cents) ?? amount(c.goal);
        const currency =
            typeof c.currency === 'string' && /^[A-Z]{3}$/.test(c.currency)
                ? c.currency
                : 'EUR';

        return [
            {
                title: title.slice(0, 160),
                raised,
                goal: goal && goal > 0 ? goal : null,
                currency,
            },
        ];
    });
}

/** Cents → "1 250 €" in the screen's language. */
export function money(
    cents: number,
    currency: string,
    language: string,
): string {
    try {
        return new Intl.NumberFormat(
            language === 'ar' ? 'ar-u-nu-latn' : language,
            {
                style: 'currency',
                currency,
                maximumFractionDigits: 0,
            },
        ).format(cents / 100);
    } catch {
        return `${Math.round(cents / 100)} ${currency}`;
    }
}
