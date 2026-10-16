import { useFlashToast } from '@/hooks/use-flash-toast';
import AuthLayoutTemplate from '@/layouts/auth/auth-simple-layout';
import { useDocumentLocale } from '@/layouts/site-layout';
import { useT } from '@/lib/i18n';

/**
 * Layout of the sign-in pages. Pages give translation keys, not text:
 * `Login.layout = { title: 'auth.login_title', description: '…' }`
 * (or `setLayoutProps` with keys); they are translated here.
 */
export default function AuthLayout({
    title = '',
    description = '',
    children,
}: {
    title?: string;
    description?: string;
    children: React.ReactNode;
}) {
    useDocumentLocale();
    useFlashToast();
    const t = useT();

    return (
        <AuthLayoutTemplate
            title={title ? t(title) : ''}
            description={description ? t(description) : ''}
        >
            {children}
        </AuthLayoutTemplate>
    );
}
