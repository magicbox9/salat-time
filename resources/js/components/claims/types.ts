/** Shapes sent by App\Http\Controllers\Claims\ClaimPresenter. */
export type ClaimStatus = 'pending' | 'approved' | 'rejected';

export const CLAIM_STATUSES: ClaimStatus[] = [
    'pending',
    'approved',
    'rejected',
];

export type ClaimMosqueRef = {
    slug: string;
    name: string;
    city: string | null;
    verified: boolean;
};

export type ClaimBase = {
    id: number;
    status: ClaimStatus;
    role_at_mosque: string;
    created_at: string | null;
    reviewed_at: string | null;
    has_document: boolean;
    document_url: string | null;
    mosque: ClaimMosqueRef | null;
};

/** What the claimant sees on /me/claims. */
export type ClaimantClaim = ClaimBase & {
    message: string | null;
    review_note: string | null;
};

export type ClaimUserRef = { id: number; name: string; email: string };

/** A row of the admin review queue. */
export type AdminClaimRow = ClaimBase & { user: ClaimUserRef | null };

/** The admin claim page. */
export type AdminClaim = AdminClaimRow & {
    phone: string | null;
    message: string | null;
    review_note: string | null;
    reviewer: { id: number; name: string } | null;
};
