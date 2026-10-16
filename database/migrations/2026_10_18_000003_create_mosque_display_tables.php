<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // How the mosque's full-screen display (TV in the prayer hall) looks and behaves.
        Schema::create('mosque_display_settings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('mosque_id')->unique()->constrained()->cascadeOnDelete();
            $table->jsonb('settings');
            $table->string('adhan_audio_path')->nullable();   // the mosque's own uploaded adhan
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });

        // Short messages the display rotates through (announcements, reminders).
        Schema::create('mosque_display_messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('mosque_id')->constrained()->cascadeOnDelete();
            $table->string('body', 500);
            $table->timestamp('starts_at')->nullable();
            $table->timestamp('ends_at')->nullable();
            $table->unsignedSmallInteger('sort')->default(0);
            $table->boolean('active')->default(true);
            $table->timestamps();
            $table->index(['mosque_id', 'active']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('mosque_display_messages');
        Schema::dropIfExists('mosque_display_settings');
    }
};
