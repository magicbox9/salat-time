<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('donations', function (Blueprint $table) {
            // The donor's language: the thank-you email may be sent days later
            // (a bank transfer confirmed by the mosque), by someone else.
            $table->string('locale', 5)->nullable()->after('message');

            // A mosque's donations list, a user's donations, PayPal webhooks.
            $table->index(['mosque_id', 'created_at']);
            $table->index('user_id');
            $table->index('paypal_capture_id');
        });

        Schema::table('mosque_payout_methods', function (Blueprint $table) {
            $table->index('verified_at');
        });
    }

    public function down(): void
    {
        Schema::table('mosque_payout_methods', function (Blueprint $table) {
            $table->dropIndex(['verified_at']);
        });

        Schema::table('donations', function (Blueprint $table) {
            $table->dropIndex(['paypal_capture_id']);
            $table->dropIndex(['user_id']);
            $table->dropIndex(['mosque_id', 'created_at']);
            $table->dropColumn('locale');
        });
    }
};
