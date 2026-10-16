<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Personal display choices (home layout, prayer-time style, adhan sound…), by feature key.
            $table->jsonb('preferences')->nullable()->after('locale');
        });

        Schema::table('mosques', function (Blueprint $table) {
            // The mosque's small website.
            $table->string('tagline', 200)->nullable()->after('description');
            $table->string('accent_color', 7)->nullable()->after('tagline');   // "#0f6b56"
            $table->jsonb('social_links')->nullable()->after('accent_color');  // {facebook, instagram, youtube, …}
        });
    }

    public function down(): void
    {
        Schema::table('mosques', function (Blueprint $table) {
            $table->dropColumn(['tagline', 'accent_color', 'social_links']);
        });
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('preferences');
        });
    }
};
