<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // People allowed to run a mosque's page (granted by an admin after a claim).
        Schema::create('mosque_managers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('mosque_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('role', 16)->default('owner');   // owner | editor
            $table->foreignId('granted_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->unique(['mosque_id', 'user_id']);
        });

        // Requests to manage a mosque, reviewed by a platform admin.
        Schema::create('mosque_claims', function (Blueprint $table) {
            $table->id();
            $table->foreignId('mosque_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('status', 16)->default('pending');  // pending | approved | rejected
            $table->string('role_at_mosque', 120);
            $table->string('phone', 40)->nullable();
            $table->text('message')->nullable();
            $table->string('document_path')->nullable();
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reviewed_at')->nullable();
            $table->text('review_note')->nullable();
            $table->timestamps();
            $table->index(['status', 'created_at']);
        });
        // At most one open claim per person and mosque.
        DB::statement("CREATE UNIQUE INDEX mosque_claims_one_pending ON mosque_claims (mosque_id, user_id) WHERE status = 'pending'");

        // Saved mosques; one of them can be the user's own mosque (primary).
        Schema::create('favorite_mosques', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('mosque_id')->constrained()->cascadeOnDelete();
            $table->boolean('is_primary')->default(false);
            $table->timestamps();
            $table->unique(['user_id', 'mosque_id']);
        });
        DB::statement('CREATE UNIQUE INDEX favorite_mosques_one_primary ON favorite_mosques (user_id) WHERE is_primary');
    }

    public function down(): void
    {
        Schema::dropIfExists('favorite_mosques');
        Schema::dropIfExists('mosque_claims');
        Schema::dropIfExists('mosque_managers');
    }
};
