<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // The personal prayer tracker. Rows come from the web (manual check-in)
        // and later from the phone apps (sensor metrics).
        Schema::create('prayer_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->date('prayer_date');
            $table->string('prayer', 8);                     // fajr | dhuhr | asr | maghrib | isha
            $table->string('status', 8);                     // on_time | late | qada | missed
            $table->timestamp('prayed_at')->nullable();
            $table->string('place', 8)->default('home');     // mosque | home | work | other
            $table->foreignId('mosque_id')->nullable()->constrained()->nullOnDelete();
            $table->boolean('in_congregation')->default(false);
            $table->string('source', 8)->default('web');     // web | ios | android
            // Phone sensors: rakaat, ruku, sujud, duration_seconds, stillness (0–1) …
            $table->jsonb('metrics')->nullable();
            $table->unsignedInteger('hasanat')->default(0);
            $table->timestamps();
            $table->unique(['user_id', 'prayer_date', 'prayer']);
            $table->index(['user_id', 'prayer_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('prayer_logs');
    }
};
