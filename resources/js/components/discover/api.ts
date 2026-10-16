/**
 * Small same-origin JSON client for the globe (searches, nearby mosques,
 * favourites). Writes carry Laravel's XSRF cookie as a header.
 */
export class RequestError extends Error {
    constructor(
        public status: number,
        message: string,
    ) {
        super(message);
    }
}

function xsrfToken(): string | null {
    if (typeof document === 'undefined') {
        return null;
    }

    const match = document.cookie.match(/(?:^|;\s*)XSRF-TOKEN=([^;]+)/);

    return match ? decodeURIComponent(match[1]) : null;
}

/** "/path" + {a: 1} → "/path?a=1" (values are encoded). */
export function withQuery(
    path: string,
    params: Record<string, string | number>,
): string {
    const query = new URLSearchParams();

    for (const [key, value] of Object.entries(params)) {
        query.set(key, String(value));
    }

    return `${path}?${query.toString()}`;
}

async function request<T>(
    method: 'GET' | 'POST' | 'PATCH' | 'DELETE',
    url: string,
    signal?: AbortSignal,
    data?: Record<string, unknown>,
): Promise<T> {
    const headers: Record<string, string> = {
        Accept: 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
    };
    const token = xsrfToken();

    if (method !== 'GET' && token) {
        headers['X-XSRF-TOKEN'] = token;
    }

    const init: RequestInit = {
        method,
        headers,
        signal,
        credentials: 'same-origin',
    };

    // Writes may carry a JSON body (GET never does).
    if (data && method !== 'GET') {
        headers['Content-Type'] = 'application/json';
        init.body = JSON.stringify(data);
    }

    const response = await fetch(url, init);
    const body = (await response.json().catch(() => null)) as
        | (T & { message?: string; errors?: Record<string, string[]> })
        | null;

    if (!response.ok) {
        const first = body?.errors
            ? Object.values(body.errors)[0]?.[0]
            : undefined;
        // Only these answers carry text written for the visitor in their
        // language; Laravel's own "Too Many Attempts." or "Unauthenticated."
        // are English, so callers fall back to a translated message.
        const translated = response.status === 422 || response.status === 503;

        throw new RequestError(
            response.status,
            translated ? (first ?? body?.message ?? '') : '',
        );
    }

    return body as T;
}

export function getJson<T>(url: string, signal?: AbortSignal): Promise<T> {
    return request<T>('GET', url, signal);
}

export function sendJson<T>(
    method: 'POST' | 'PATCH' | 'DELETE',
    url: string,
    data?: Record<string, unknown>,
): Promise<T> {
    return request<T>(method, url, undefined, data);
}

export function isAbort(error: unknown): boolean {
    return error instanceof DOMException && error.name === 'AbortError';
}
