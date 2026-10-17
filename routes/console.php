<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Expire unconfirmed bank pledges and close campaigns that have ended.
Schedule::command('fundraising:tidy')->dailyAt('03:15')->withoutOverlapping();
