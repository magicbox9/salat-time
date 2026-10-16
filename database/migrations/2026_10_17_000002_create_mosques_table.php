<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('mosques', function (Blueprint $table) {
            $table->id();
            $table->string('slug', 160)->unique();
            $table->string('name', 200);
            $table->string('search_name', 260)->index();   // lowercase, accents removed (fuzzy search)
            $table->string('address', 300)->nullable();
            $table->string('postcode', 16)->nullable();
            $table->string('city', 120)->nullable();
            $table->char('country_code', 2)->default('FR');
            $table->string('territory', 8)->nullable();      // FR, YT, RE, GP, MQ, GF, NC …
            $table->decimal('latitude', 9, 6);
            $table->decimal('longitude', 9, 6);
            $table->string('timezone', 64)->default('Europe/Paris');
            $table->string('association', 200)->nullable();
            $table->string('website', 300)->nullable();
            $table->string('phone', 40)->nullable();
            $table->string('email', 200)->nullable();
            $table->text('description')->nullable();
            $table->string('logo_path')->nullable();
            $table->string('cover_path')->nullable();
            // Where the record came from: mawaqit | directory | osm | manual
            $table->string('source', 16);
            $table->string('mawaqit_slug', 200)->nullable()->unique();
            $table->unsignedBigInteger('mawaqit_id')->nullable();
            $table->string('directory_id', 32)->nullable()->index();
            $table->string('osm_ref', 40)->nullable()->index();
            $table->string('jumua', 5)->nullable();
            $table->string('jumua2', 5)->nullable();
            $table->string('jumua3', 5)->nullable();
            $table->boolean('jumua_as_dhuhr')->default(false);
            // Documents and finances checked by the platform (needed before fundraising).
            $table->timestamp('verified_at')->nullable();
            $table->timestamps();
        });

        DB::statement('CREATE INDEX mosques_search_name_trgm ON mosques USING gin (search_name gin_trgm_ops)');
        DB::statement('CREATE INDEX mosques_city_trgm ON mosques USING gin (lower(city) gin_trgm_ops)');
        // Nearest-mosque queries (earthdistance).
        DB::statement('CREATE INDEX mosques_earth ON mosques USING gist (ll_to_earth(latitude::float8, longitude::float8))');
    }

    public function down(): void
    {
        Schema::dropIfExists('mosques');
    }
};
