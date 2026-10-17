<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('mosques', function (Blueprint $table) {
            // When the default blog categories (Khutbah, News, …) were created for the
            // mosque's managers. Set once: categories a manager deletes do not come back.
            $table->timestamp('post_categories_seeded_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('mosques', function (Blueprint $table) {
            $table->dropColumn('post_categories_seeded_at');
        });
    }
};
