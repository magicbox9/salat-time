import { usePage } from '@inertiajs/react';
import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from '@/components/ui/select';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { countryFlag, sortedCountries } from './countries';

type Props = {
    value: string;
    onChange: (code: string) => void;
    glass: boolean;
    compact?: boolean;
};

/** Country of the address being searched (France first). */
export function CountrySelect({
    value,
    onChange,
    glass,
    compact = false,
}: Props) {
    const t = useT();
    const { locale } = usePage().props;
    const countries = sortedCountries(locale);

    return (
        <Select value={value} onValueChange={onChange}>
            <SelectTrigger
                aria-label={t('discover.country')}
                className={cn(
                    'h-11 shrink-0 rounded-xl',
                    compact ? 'w-[4.5rem]' : 'w-full sm:w-44',
                    glass &&
                        'border-white/20 bg-white/10 text-white hover:bg-white/15 dark:bg-white/10 [&_svg:not([class*=text-])]:text-white/70',
                )}
            >
                <SelectValue>
                    <span aria-hidden>{countryFlag(value)}</span>
                    {!compact && (
                        <span className="truncate">
                            {countries.find((c) => c.code === value)?.name ??
                                value}
                        </span>
                    )}
                </SelectValue>
            </SelectTrigger>
            <SelectContent className="max-h-72">
                {countries.map((country) => (
                    <SelectItem key={country.code} value={country.code}>
                        <span aria-hidden>{countryFlag(country.code)}</span>
                        {country.name}
                    </SelectItem>
                ))}
            </SelectContent>
        </Select>
    );
}
