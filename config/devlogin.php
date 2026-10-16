<?php

/*
 * One-click sign-in as the seeded test accounts (database/seeders/DevSeeder.php).
 * Development only: it never turns on outside APP_ENV=local, even if DEV_LOGIN=true.
 * To remove the feature: delete this file, routes/modules/dev-login.php,
 * app/Http/Controllers/Dev/, resources/js/components/dev-login-panel.tsx,
 * lang/{en,fr,ar}/devlogin.json and the two lines marked "dev login".
 */

return [
    'enabled' => env('DEV_LOGIN', false) && env('APP_ENV') === 'local',

    'accounts' => [
        'admin' => 'admin@salat-time.test',
        'manager' => 'manager@salat-time.test',
        'user' => 'user@salat-time.test',
    ],
];
