<?php

/*
|--------------------------------------------------------------------------
| Calculated prayer times
|--------------------------------------------------------------------------
|
| A mosque's own published calendar always comes first. When a mosque
| publishes none, the page shows times calculated with the "France — mosque
| convention" method (resources/prayer-method, SPEC.md), always labelled as
| calculated and never as the mosque's own.
|
*/

return [

    // The département table is learned from calendars published on Mawaqit
    // (decision D1 in Prayer Times Study/final-method/FINDINGS.md §8). Until
    // the owner clears it, it can be switched off: metropolitan France then
    // uses "UOIF 12° with safety minutes" everywhere (64 % of prayer-days
    // within 2 minutes instead of 69 %).
    'france_table' => (bool) env('PRAYER_FRANCE_TABLE', true),

    // Overseas territories and other countries: a standard method from
    // resources/prayer-method/standard_methods.json.
    'elsewhere' => env('PRAYER_METHOD_ELSEWHERE', 'mwl'),

];
