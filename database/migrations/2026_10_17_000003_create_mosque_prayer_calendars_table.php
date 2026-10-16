<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // One published yearly calendar per mosque, as the mosque shows it on Mawaqit:
        // days = 12 months × days × [fajr, shuruq, dhuhr, asr, maghrib, isha] ("HH:MM", local time)
        // iqama = 12 months × days × 5 values ("+10" minutes after the adhan, or "HH:MM")
        Schema::create('mosque_prayer_calendars', function (Blueprint $table) {
            $table->id();
            $table->foreignId('mosque_id')->constrained()->cascadeOnDelete();
            $table->smallInteger('year');
            $table->string('source', 16)->default('mawaqit');
            $table->string('timezone', 64);
            $table->jsonb('days');
            $table->jsonb('iqama')->nullable();
            $table->unsignedSmallInteger('imsak_minutes')->nullable();
            $table->timestamp('retrieved_at')->nullable();
            $table->timestamps();
            $table->unique(['mosque_id', 'year']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('mosque_prayer_calendars');
    }
};
