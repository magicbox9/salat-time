import { router } from '@inertiajs/react';
import { Search, X } from 'lucide-react';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from '@/components/ui/select';
import { useT } from '@/lib/i18n';

type Query = Record<string, string | null | undefined>;

/** Reloads the current admin list with new query-string filters (page resets to 1). */
export function useApplyFilters(
    path: string,
    current: Query,
): (changes: Query) => void {
    return (changes) => {
        const next: Record<string, string> = {};

        for (const [key, value] of Object.entries({ ...current, ...changes })) {
            if (value) {
                next[key] = value;
            }
        }

        router.get(path, next, {
            preserveState: true,
            preserveScroll: true,
            replace: true,
        });
    };
}

/** A search field that applies on submit, with a clear button. */
export function SearchField({
    value,
    placeholder,
    onSearch,
}: {
    value: string | null;
    placeholder: string;
    onSearch: (term: string | null) => void;
}) {
    const t = useT();
    const [term, setTerm] = useState(value ?? '');
    const [shown, setShown] = useState(value);

    // The page kept its state (tabs, back button) but the server's term changed:
    // show the term the list is really filtered by.
    if (value !== shown) {
        setShown(value);
        setTerm(value ?? '');
    }

    return (
        <form
            role="search"
            className="flex w-full gap-2 sm:max-w-md"
            onSubmit={(event) => {
                event.preventDefault();
                onSearch(term.trim() || null);
            }}
        >
            <div className="relative flex-1">
                <Search
                    className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground"
                    aria-hidden
                />
                <Input
                    type="search"
                    value={term}
                    maxLength={100}
                    onChange={(event) => setTerm(event.target.value)}
                    placeholder={placeholder}
                    aria-label={placeholder}
                    className="ps-9"
                />
            </div>
            <Button type="submit" variant="secondary">
                {t('admin.search')}
            </Button>
            {value && (
                <Button
                    type="button"
                    variant="ghost"
                    size="icon"
                    aria-label={t('admin.clear_search')}
                    onClick={() => {
                        setTerm('');
                        onSearch(null);
                    }}
                >
                    <X />
                </Button>
            )}
        </form>
    );
}

const ANY = '__any';

/** A compact select filter; "any" clears it. */
export function FilterSelect({
    label,
    value,
    options,
    onChange,
}: {
    label: string;
    value: string | null;
    options: { value: string; label: string }[];
    onChange: (value: string | null) => void;
}) {
    const t = useT();

    return (
        <Select
            value={value ?? ANY}
            onValueChange={(next) => onChange(next === ANY ? null : next)}
        >
            <SelectTrigger
                className="w-full sm:w-auto sm:min-w-40"
                aria-label={label}
            >
                <span className="text-muted-foreground">{label}:</span>
                <SelectValue />
            </SelectTrigger>
            <SelectContent>
                <SelectItem value={ANY}>{t('admin.filter_any')}</SelectItem>
                {options.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                        {option.label}
                    </SelectItem>
                ))}
            </SelectContent>
        </Select>
    );
}
