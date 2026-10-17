/** Shapes sent by App\Services\Fundraising\CampaignPresenter and the fundraising controllers. */

export type CampaignKind =
    | 'building'
    | 'zakat'
    | 'sadaqa'
    | 'iftar'
    | 'education'
    | 'project';

export type CampaignStatus =
    | 'draft'
    | 'pending'
    | 'active'
    | 'completed'
    | 'closed'
    | 'rejected';

/** The stored status, with "active" split into upcoming / active / ended. */
export type CampaignState = CampaignStatus | 'upcoming' | 'ended';

export type DonationStatus =
    | 'pending'
    | 'completed'
    | 'cancelled'
    | 'failed'
    | 'refunded';

export type DonationMethod = 'paypal' | 'bank';

export type CampaignMosque = {
    id: number;
    slug: string;
    name: string;
    city: string | null;
    country_code: string;
    verified: boolean;
    logo_url: string | null;
};

export type CampaignTotals = {
    currency: string;
    goal: number;
    raised: number;
    pledged: number;
    donors_count: number;
    percent: number;
};

export type CampaignCardData = CampaignTotals & {
    id: number;
    slug: string;
    kind: CampaignKind;
    title: string;
    summary: string;
    cover_url: string | null;
    status: CampaignStatus;
    state: CampaignState;
    starts_at: string | null;
    ends_at: string | null;
    days_left: number | null;
    mosque: CampaignMosque | null;
    distance_m: number | null;
};

export type CampaignDetail = CampaignCardData & {
    story_html: string;
    show_donor_names: boolean;
    created_at: string | null;
};

export type WallEntry = {
    id: number;
    name: string | null;
    amount: number;
    currency: string;
    message: string | null;
    at: string | null;
};

/** GET /campaigns/{slug}/progress.json */
export type CampaignProgress = CampaignTotals & {
    status: CampaignStatus;
    state: CampaignState;
    days_left: number | null;
    recent: WallEntry[];
    updated_at: string;
};

export type CampaignUpdateData = {
    id: number;
    title: string;
    body_html: string;
    created_at: string | null;
};

export type PayPalConfig = {
    client_id: string;
    merchant: string;
    sdk_url: string;
    sandbox: boolean;
};

export type AvailableMethods = { paypal: boolean; bank: boolean };

export type BankTransfer = {
    account_holder: string | null;
    iban: string;
    bic: string | null;
    bank_name: string | null;
};

export type PayoutMethod = {
    id: number;
    type: DonationMethod;
    paypal_email: string | null;
    paypal_merchant_id: string | null;
    account_holder: string | null;
    iban_masked: string | null;
    bic: string | null;
    bank_name: string | null;
    verified: boolean;
    verified_at: string | null;
    updated_at: string | null;
};

/** A payout method in the admin's lists (App\Http\Controllers\Admin\Fundraising\PayoutReviewController::row). */
export type AdminPayoutRow = PayoutMethod & {
    /** The reviewed details' version, sent back when verifying them. */
    version: string;
    verified_by: string | null;
    mosque: {
        slug: string;
        name: string;
        city: string | null;
        verified: boolean;
    } | null;
};

/** A donation as the mosque's managers see it. */
export type ManagedDonation = {
    id: number;
    reference: string;
    donor_name: string | null;
    donor_email: string | null;
    anonymous: boolean;
    message: string | null;
    amount: number;
    currency: string;
    method: DonationMethod;
    status: DonationStatus;
    created_at: string | null;
    confirmed_at: string | null;
    campaign: { slug: string; title: string } | null;
    can_confirm: boolean;
};

/** Why a campaign cannot go to review yet ("fundraising.problem_{key}"). */
export type EligibilityProblem =
    | 'mosque_unverified'
    | 'no_verified_payout'
    | 'no_method'
    | 'method_unverified'
    | 'ended';

export const CAMPAIGN_KINDS: CampaignKind[] = [
    'building',
    'zakat',
    'sadaqa',
    'iftar',
    'education',
    'project',
];
