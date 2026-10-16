/**
 * Small JSON client for the mosque page's live pieces (feed, comments,
 * favourites). Same-origin only; Laravel's XSRF cookie protects writes.
 */
export class ApiError extends Error {
    constructor(
        public status: number,
        public errors: Record<string, string[]> = {},
        message = '',
    ) {
        super(message || `HTTP ${status}`);
    }

    /**
     * First validation message (422 only: Laravel translates those). Other
     * errors carry English framework text, never shown to visitors.
     */
    firstError(): string | null {
        if (this.status !== 422) {
            return null;
        }

        const first = Object.values(this.errors)[0];

        return (
            first?.[0] ??
            (this.message.startsWith('HTTP ') ? null : this.message)
        );
    }
}

function xsrfToken(): string | null {
    if (typeof document === 'undefined') {
        return null;
    }

    const match = document.cookie.match(/(?:^|;\s*)XSRF-TOKEN=([^;]+)/);

    return match ? decodeURIComponent(match[1]) : null;
}

type Method = 'GET' | 'POST' | 'PATCH' | 'DELETE';

export async function api<T>(
    method: Method,
    url: string,
    body?: Record<string, unknown>,
    init: { redirect?: RequestRedirect } = {},
): Promise<T> {
    const headers: Record<string, string> = {
        Accept: 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
    };
    const token = xsrfToken();

    if (token && method !== 'GET') {
        headers['X-XSRF-TOKEN'] = token;
    }

    if (body) {
        headers['Content-Type'] = 'application/json';
    }

    const response = await fetch(url, {
        method,
        headers,
        body: body ? JSON.stringify(body) : undefined,
        credentials: 'same-origin',
        redirect: init.redirect ?? 'follow',
    });

    // A redirect we chose not to follow means the action was accepted.
    if (response.type === 'opaqueredirect') {
        return undefined as T;
    }

    const data = response.headers
        .get('content-type')
        ?.includes('application/json')
        ? await response.json().catch(() => null)
        : null;

    if (!response.ok) {
        throw new ApiError(
            response.status,
            data?.errors ?? {},
            data?.message ?? '',
        );
    }

    return data as T;
}

/** Turns an error into the message a visitor should read. */
export function errorMessage(
    error: unknown,
    t: (key: string) => string,
): string {
    if (error instanceof ApiError) {
        if (error.status === 429) {
            return t('mosque.too_many');
        }

        if (error.status === 401) {
            return t('mosque.login_needed');
        }

        if (error.status === 403) {
            return t('mosque.not_allowed');
        }

        if (error.status === 419) {
            return t('mosque.session_expired');
        }

        return error.firstError() ?? t('site.error_generic');
    }

    return t('site.error_generic');
}
