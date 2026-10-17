import InputError from '@/components/input-error';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { useT } from '@/lib/i18n';

/** Lowercase ASCII words joined by hyphens, as the server makes them (Arabic is left to the server). */
export function slugify(text: string, max = 200): string {
    return (
        text
            .normalize('NFKD')
            .replace(/[̀-ͯ]/g, '')
            .toLowerCase()
            // Letters NFKD does not split, spelled as the server spells them ("œuvre" → "oeuvre").
            .replace(/œ/g, 'oe')
            .replace(/æ/g, 'ae')
            .replace(/ß/g, 'ss')
            .replace(/['’]/g, '')
            .replace(/[^a-z0-9]+/g, '-')
            .replace(/^-+|-+$/g, '')
            .slice(0, max)
            .replace(/-+$/g, '')
    );
}

/** A slug as the server accepts it: no hyphen at either end. */
export function trimSlug(value: string): string {
    return value.replace(/^-+|-+$/g, '');
}

type Props = {
    /** The address before the slug, e.g. "/mosques/el-houda/blog/". */
    prefix: string;
    value: string;
    onChange: (value: string) => void;
    max: number;
    error?: string;
};

/** The address of a post or page: made from the title, editable. */
export function SlugField({ prefix, value, onChange, max, error }: Props) {
    const t = useT();

    return (
        <div className="grid gap-1.5">
            <Label htmlFor="slug">{t('manage.slug')}</Label>
            <div
                className="flex min-w-0 items-stretch overflow-hidden rounded-md border shadow-xs focus-within:ring-[3px] focus-within:ring-ring/50"
                dir="ltr"
            >
                <span className="hidden max-w-[50%] items-center truncate border-e bg-muted px-3 text-sm text-muted-foreground sm:flex">
                    {prefix}
                </span>
                <Input
                    id="slug"
                    value={value}
                    maxLength={max}
                    placeholder={t('manage.slug_placeholder')}
                    onChange={(event) =>
                        onChange(
                            event.target.value
                                .toLowerCase()
                                .replace(/[^a-z0-9-]/g, '-')
                                .replace(/-{2,}/g, '-'),
                        )
                    }
                    // Only a real change counts as editing: tabbing through keeps the slug following the title.
                    onBlur={() =>
                        trimSlug(value) !== value && onChange(trimSlug(value))
                    }
                    aria-invalid={error ? true : undefined}
                    className="rounded-none border-0 font-mono text-sm shadow-none focus-visible:ring-0"
                />
            </div>
            {!error && (
                <p className="text-xs text-muted-foreground">
                    {t('manage.slug_hint')}
                </p>
            )}
            <InputError message={error} />
        </div>
    );
}
