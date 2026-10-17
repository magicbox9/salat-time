<?php

/*
|--------------------------------------------------------------------------
| Fundraising — campaigns of mosques
|--------------------------------------------------------------------------
|
| The platform never holds money (AGENTS.md rule 6). A donation goes straight
| to the mosque: PayPal Checkout with the mosque's own verified PayPal account
| as the payee, or a bank transfer to its verified IBAN, which the mosque
| confirms once received. Amounts are integer cents.
|
| PayPal is optional: without a client id and secret, the PayPal method is
| simply not offered (bank transfers still work) and admins see a notice.
| PayPal stays in sandbox until the owner sets PAYPAL_MODE=live.
|
*/

return [
    // Days after which a bank-transfer pledge the mosque never confirmed expires (fundraising:tidy).
    'pledge_expiry_days' => (int) env('FUNDRAISING_PLEDGE_EXPIRY_DAYS', 30),


    // ISO 4217 code of every campaign and donation.
    'currency' => 'EUR',

    // One donation: 1 € to 100,000 €.
    'min_amount' => 100,
    'max_amount' => 10_000_000,

    // Suggested amounts on the donate panel (cents).
    'presets' => [1000, 2000, 5000, 10000, 25000],

    // A campaign's goal: 100 € to 10,000,000 €.
    'goal_min' => 10_000,
    'goal_max' => 1_000_000_000,

    // Live progress (GET /campaigns/{slug}/progress.json) is cached this long.
    'progress_cache_seconds' => 5,

    // A mosque's active campaigns (GET /mosques/{slug}/campaigns.json).
    'mosque_cache_seconds' => 30,

    // How many completed donations the campaign page lists.
    'wall_size' => 12,

    'paypal' => [
        'mode' => env('PAYPAL_MODE', 'sandbox') === 'live' ? 'live' : 'sandbox',
        'client_id' => env('PAYPAL_CLIENT_ID'),
        'client_secret' => env('PAYPAL_CLIENT_SECRET'),
        'webhook_id' => env('PAYPAL_WEBHOOK_ID'),

        'api' => [
            'sandbox' => 'https://api-m.sandbox.paypal.com',
            'live' => 'https://api-m.paypal.com',
        ],
        'sdk_url' => 'https://www.paypal.com/sdk/js',

        // Seconds; requests are retried twice on connection errors.
        'timeout' => 15,

        // Shown on the donor's card statement after "PAYPAL *" (22 characters at
        // most). Unset by default: the statement then shows the mosque's own
        // PayPal descriptor, since the mosque is the one being paid.
        'soft_descriptor' => env('PAYPAL_SOFT_DESCRIPTOR'),

        // The PayPal page names the mosque being paid; this is only the
        // fallback when a mosque has no name.
        'brand_name' => env('PAYPAL_BRAND_NAME', 'Salat Time'),
    ],

];
