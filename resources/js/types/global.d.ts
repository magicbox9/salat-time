import type { Auth } from '@/types/auth';

declare module 'react' {
    interface InputHTMLAttributes<T> {
        passwordrules?: string;
    }
}

declare module '@inertiajs/core' {
    export interface InertiaConfig {
        sharedPageProps: {
            name: string;
            auth: Auth;
            sidebarOpen: boolean;
            locale: 'en' | 'fr' | 'ar';
            dir: 'ltr' | 'rtl';
            locales: Record<string, string>;
            ui: Record<string, string>;
            [key: string]: unknown;
        };
    }
}
