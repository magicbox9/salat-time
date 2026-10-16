import {
    DoorOpen,
    Droplets,
    HandHeart,
    HeartHandshake,
    House,
    LogIn,
    LogOut,
    Moon,
    Sparkles,
    Sun,
    Sunrise,
    Sunset,
    Utensils,
    UtensilsCrossed,
} from 'lucide-react';
import type { LucideIcon } from 'lucide-react';

export type AdhkarCategory = {
    key: string;
    /** Number of adhkar in the category. */
    count: number;
    name_ar: string;
};

export type AdhkarAudio = { url: string; credit: string; credit_url: string };

export type Dhikr = {
    id: string;
    arabic: string;
    /** How many times to say it. */
    count: number;
    count_desc: string | null;
    virtue: string | null;
    /** The English meaning (Hisn al-Muslim's translation), when given. */
    meaning_en: string | null;
    source: string | null;
    audio: AdhkarAudio | null;
};

export const CATEGORY_ICONS: Record<string, LucideIcon> = {
    morning: Sunrise,
    evening: Sunset,
    post_prayer: HandHeart,
    sleep: Moon,
    waking: Sun,
    after_ablution: Droplets,
    entering_mosque: LogIn,
    leaving_mosque: LogOut,
    before_eating: Utensils,
    after_eating: UtensilsCrossed,
    entering_home: House,
    leaving_home: DoorOpen,
    distress: HeartHandshake,
    forgiveness: Sparkles,
};

export function categoryIcon(key: string): LucideIcon {
    return CATEGORY_ICONS[key] ?? Sparkles;
}

/**
 * Which category fits the visitor's local time: morning adhkar until early
 * afternoon, evening adhkar after that; sleep adhkar late at night.
 */
export function suggestedCategories(now: Date): {
    primary: 'morning' | 'evening';
    night: boolean;
} {
    const hour = now.getHours();

    return {
        primary: hour >= 3 && hour < 14 ? 'morning' : 'evening',
        night: hour >= 21 || hour < 3,
    };
}
