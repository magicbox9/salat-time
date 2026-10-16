import { AlertCircleIcon } from 'lucide-react';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { useT } from '@/lib/i18n';

/**
 * Lists error messages. Each message may be a translation key
 * (e.g. "settings.error_qr_code"); plain text is shown unchanged.
 */
export default function AlertError({
    errors,
    title,
}: {
    errors: string[];
    title?: string;
}) {
    const t = useT();

    return (
        <Alert variant="destructive">
            <AlertCircleIcon />
            <AlertTitle>{title || t('settings.error_title')}</AlertTitle>
            <AlertDescription>
                <ul className="list-inside list-disc text-sm">
                    {Array.from(new Set(errors)).map((error, index) => (
                        <li key={index}>{t(error)}</li>
                    ))}
                </ul>
            </AlertDescription>
        </Alert>
    );
}
