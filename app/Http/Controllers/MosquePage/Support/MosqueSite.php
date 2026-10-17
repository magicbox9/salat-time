<?php

namespace App\Http\Controllers\MosquePage\Support;

use App\Models\Campaign;
use App\Models\Mosque;
use App\Models\MosquePage;
use App\Support\Markdown;
use Illuminate\Database\Eloquent\Collection;

/**
 * The frame of every page of a mosque's site: its header band (cover, logo,
 * name, tagline, colour) and its menu (published pages marked for the menu,
 * the Khutbahs category, donations when a campaign is open).
 */
final class MosqueSite
{
    private const MENU_PAGES = 8;

    /** Slugs a mosque's "About us" page usually takes. */
    public const ABOUT_SLUGS = ['about', 'about-us', 'a-propos', 'qui-sommes-nous', 'mn-nhn'];

    public const CONTACT_SLUG = 'contact';

    /** @return array<string, mixed> */
    public static function shell(Mosque $mosque): array
    {
        /** @var Collection<int, MosquePage> $pages */
        $pages = $mosque->pages()
            ->whereNotNull('published_at')
            ->where('published_at', '<=', now())
            ->where('show_in_menu', true)
            ->orderBy('sort')
            ->orderBy('title')
            ->limit(self::MENU_PAGES + 1)
            ->get(['id', 'title', 'slug']);
        $contact = $pages->firstWhere('slug', self::CONTACT_SLUG);

        return [
            'slug' => $mosque->slug,
            'name' => $mosque->name,
            'tagline' => $mosque->tagline,
            'city' => $mosque->city,
            'timezone' => $mosque->timezone,
            'verified' => $mosque->isVerified(),
            'logo_url' => PostPresenter::url($mosque->logo_path),
            'cover_url' => PostPresenter::url($mosque->cover_path),
            'accent' => AccentColor::present($mosque->accent_color),
            'menu' => $pages->reject(fn (MosquePage $page) => $page->slug === self::CONTACT_SLUG)
                ->take(self::MENU_PAGES)
                ->map(fn (MosquePage $page) => ['title' => $page->title, 'slug' => $page->slug])
                ->values()
                ->all(),
            'contact_page' => $contact?->slug,
            'khutbah' => $mosque->postCategories()->where('slug', BlogPosts::KHUTBAH)->exists(),
            'donate' => Campaign::query()
                ->where('mosque_id', $mosque->id)
                ->whereNull('deleted_at')
                ->where('status', 'active')
                ->where(fn ($q) => $q->whereNull('ends_at')->orWhere('ends_at', '>', now()))
                ->exists(),
        ];
    }

    /**
     * Title, description and picture for search engines and link previews.
     *
     * @return array{title: string, description: string, image: string|null, url: string, type: string}
     */
    public static function meta(string $title, ?string $markdown, ?string $image, string $url, string $type = 'website'): array
    {
        return [
            'title' => $title,
            'description' => Markdown::excerpt($markdown, 160),
            'image' => $image,
            'url' => $url,
            'type' => $type,
        ];
    }
}
