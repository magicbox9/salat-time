<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Blog categories of a mosque's site (Khutbah, News, Events, Education, …).
        Schema::create('mosque_post_categories', function (Blueprint $table) {
            $table->id();
            $table->foreignId('mosque_id')->constrained()->cascadeOnDelete();
            $table->string('name', 80);
            $table->string('slug', 90);
            $table->string('description', 300)->nullable();
            $table->unsignedSmallInteger('sort')->default(0);
            $table->timestamps();
            $table->unique(['mosque_id', 'slug']);
        });

        Schema::table('mosque_posts', function (Blueprint $table) {
            $table->foreignId('category_id')->nullable()->after('author_id')
                ->constrained('mosque_post_categories')->nullOnDelete();
            $table->string('slug', 220)->nullable()->after('title');
            $table->string('excerpt', 400)->nullable()->after('slug');
            $table->string('video_url', 500)->nullable()->after('image_path');     // YouTube / Vimeo (khutbah recordings)
            $table->string('attachment_path')->nullable()->after('video_url');     // PDF (khutbah text, programme)
            $table->string('attachment_name', 200)->nullable()->after('attachment_path');
            $table->unique(['mosque_id', 'slug']);
        });

        // Static pages of a mosque's site (About us, Courses, Contact, …). Body is Markdown.
        Schema::create('mosque_pages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('mosque_id')->constrained()->cascadeOnDelete();
            $table->foreignId('author_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('title', 160);
            $table->string('slug', 170);
            $table->text('body');
            $table->unsignedSmallInteger('sort')->default(0);
            $table->boolean('show_in_menu')->default(true);
            $table->timestamp('published_at')->nullable();
            $table->timestamps();
            $table->softDeletes();
            $table->unique(['mosque_id', 'slug']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('mosque_pages');
        Schema::table('mosque_posts', function (Blueprint $table) {
            $table->dropUnique(['mosque_id', 'slug']);
            $table->dropConstrainedForeignId('category_id');
            $table->dropColumn(['slug', 'excerpt', 'video_url', 'attachment_path', 'attachment_name']);
        });
        Schema::dropIfExists('mosque_post_categories');
    }
};
