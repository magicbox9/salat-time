<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('quran_bookmarks', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->unsignedSmallInteger('surah');
            $table->unsignedSmallInteger('ayah');
            $table->string('note', 500)->nullable();
            $table->timestamps();
            $table->unique(['user_id', 'surah', 'ayah']);
        });

        // Address → coordinates answers, so each address is only looked up once.
        Schema::create('geocode_cache', function (Blueprint $table) {
            $table->id();
            $table->string('query_hash', 64)->unique();
            $table->string('query', 300);
            $table->string('provider', 16);
            $table->jsonb('results');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('geocode_cache');
        Schema::dropIfExists('quran_bookmarks');
    }
};
