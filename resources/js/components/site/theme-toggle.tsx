import { Moon, Sun } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useAppearance } from '@/hooks/use-appearance';
import { useT } from '@/lib/i18n';

export function ThemeToggle() {
    const { resolvedAppearance, updateAppearance } = useAppearance();
    const t = useT();
    const dark = resolvedAppearance === 'dark';

    return (
        <Button
            variant="ghost"
            size="icon"
            aria-label={t('site.theme')}
            onClick={() => updateAppearance(dark ? 'light' : 'dark')}
        >
            {dark ? <Sun className="size-5" /> : <Moon className="size-5" />}
        </Button>
    );
}
