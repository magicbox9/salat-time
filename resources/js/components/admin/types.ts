import type { MosqueSummary } from '@/types/mosque';

/** App\Http\Controllers\Admin\AdminController::paginated() */
export type Paginated<T> = {
    data: T[];
    current_page: number;
    last_page: number;
    total: number;
    from: number | null;
    to: number | null;
    prev_page_url: string | null;
    next_page_url: string | null;
};

/** Sent with every admin page (badge on the "Requests" tab). */
export type AdminPageProps = {
    pendingClaimsCount: number;
};

export type AdminMosqueRow = MosqueSummary & { managers_count: number };

export type AdminManager = {
    id: number;
    name: string;
    email: string;
    role: string;
    since: string | null;
    granted_by?: string | null;
};

export type AdminUserRow = {
    id: number;
    name: string;
    email: string;
    is_admin: boolean;
    verified: boolean;
    joined_at: string | null;
    managed_count: number;
    is_self: boolean;
};

export type AdminStats = {
    mosques: number;
    mosques_with_times: number;
    mosques_verified: number;
    users: number;
    managers: number;
    admins: number;
    claims_pending: number;
    posts: number;
    comments: number;
};
