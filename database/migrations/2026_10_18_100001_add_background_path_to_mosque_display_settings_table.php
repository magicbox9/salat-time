<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('mosque_display_settings', function (Blueprint $table) {
            // The mosque's own background picture for its screen (public disk, display/{id}/).
            $table->string('background_path')->nullable()->after('adhan_audio_path');
        });
    }

    public function down(): void
    {
        Schema::table('mosque_display_settings', function (Blueprint $table) {
            $table->dropColumn('background_path');
        });
    }
};
