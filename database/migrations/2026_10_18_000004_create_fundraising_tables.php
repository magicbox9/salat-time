<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Where donations go: the mosque's own PayPal account or bank account.
        // The platform never holds the money. An admin verifies each method.
        Schema::create('mosque_payout_methods', function (Blueprint $table) {
            $table->id();
            $table->foreignId('mosque_id')->constrained()->cascadeOnDelete();
            $table->string('type', 8);                          // paypal | bank
            $table->string('paypal_email', 200)->nullable();
            $table->string('paypal_merchant_id', 40)->nullable();
            $table->string('account_holder', 200)->nullable();
            $table->text('iban')->nullable();                   // encrypted at rest
            $table->string('bic', 11)->nullable();
            $table->string('bank_name', 120)->nullable();
            $table->timestamp('verified_at')->nullable();
            $table->foreignId('verified_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->unique(['mosque_id', 'type']);
        });

        // A fundraising campaign (building, zakat, iftar, a project…). Amounts in cents.
        Schema::create('campaigns', function (Blueprint $table) {
            $table->id();
            $table->foreignId('mosque_id')->constrained()->cascadeOnDelete();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('slug', 140)->unique();
            $table->string('kind', 16)->default('project');     // building | zakat | sadaqa | iftar | education | project
            $table->string('title', 160);
            $table->string('summary', 300);
            $table->text('story');                               // Markdown
            $table->string('cover_path')->nullable();
            $table->char('currency', 3)->default('EUR');
            $table->unsignedBigInteger('goal_amount');
            $table->unsignedBigInteger('raised_amount')->default(0);   // completed donations (cache)
            $table->unsignedBigInteger('pledged_amount')->default(0);  // bank transfers announced, not yet confirmed
            $table->unsignedInteger('donors_count')->default(0);
            $table->boolean('allow_paypal')->default(true);
            $table->boolean('allow_bank')->default(true);
            $table->boolean('show_donor_names')->default(true);
            $table->string('status', 16)->default('draft');      // draft | pending | active | completed | closed | rejected
            $table->text('review_note')->nullable();
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reviewed_at')->nullable();
            $table->timestamp('starts_at')->nullable();
            $table->timestamp('ends_at')->nullable();
            $table->timestamps();
            $table->softDeletes();
            $table->index(['status', 'mosque_id']);
        });

        Schema::create('donations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('campaign_id')->constrained()->cascadeOnDelete();
            $table->foreignId('mosque_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('donor_name', 120)->nullable();
            $table->string('donor_email', 200)->nullable();
            $table->boolean('anonymous')->default(false);
            $table->string('message', 500)->nullable();
            $table->unsignedBigInteger('amount');                // cents
            $table->char('currency', 3)->default('EUR');
            $table->string('method', 8);                         // paypal | bank
            $table->string('status', 12)->default('pending');    // pending | completed | cancelled | failed | refunded
            $table->string('reference', 24)->unique();           // shown to the donor (bank transfer reference)
            $table->string('paypal_order_id', 64)->nullable()->unique();
            $table->string('paypal_capture_id', 64)->nullable();
            $table->foreignId('confirmed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('confirmed_at')->nullable();
            $table->jsonb('provider_payload')->nullable();
            $table->timestamps();
            $table->index(['campaign_id', 'status']);
        });

        // News about a campaign ("the roof is done").
        Schema::create('campaign_updates', function (Blueprint $table) {
            $table->id();
            $table->foreignId('campaign_id')->constrained()->cascadeOnDelete();
            $table->foreignId('author_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('title', 160);
            $table->text('body');
            $table->timestamps();
        });

        DB::statement('ALTER TABLE donations ADD CONSTRAINT donations_amount_positive CHECK (amount > 0)');
        DB::statement('ALTER TABLE campaigns ADD CONSTRAINT campaigns_goal_positive CHECK (goal_amount > 0)');
    }

    public function down(): void
    {
        Schema::dropIfExists('campaign_updates');
        Schema::dropIfExists('donations');
        Schema::dropIfExists('campaigns');
        Schema::dropIfExists('mosque_payout_methods');
    }
};
