import { usePage } from '@inertiajs/react';

/**
 * "Sign in to do this": the sign-in page, then back to `path` once signed
 * in or signed up (GET /sign-in, App\Http\Controllers\Auth\SignInReturnController).
 */
export function signInUrl(path: string): string {
    return `/sign-in?return=${encodeURIComponent(path)}`;
}

/** The sign-in page, then back to the page being shown. */
export function useSignInUrl(): string {
    return signInUrl(usePage().url);
}
