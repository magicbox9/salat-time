<?php

namespace App\Http\Controllers\Quran;

use App\Http\Controllers\Controller;
use App\Models\QuranBookmark;
use App\Services\Content\QuranCorpus;
use App\Services\Content\QuranTranslations;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

/** The surah index and the reader (KFGQPC Hafs text, verbatim). */
class QuranController extends Controller
{
    public function index(Request $request, QuranCorpus $corpus): Response
    {
        $bookmarks = $request->user()
            ? QuranBookmark::query()->where('user_id', $request->user()->id)
                ->latest('updated_at')->latest('id')->limit(100)
                ->get(['id', 'surah', 'ayah', 'note', 'updated_at'])
                ->map(fn (QuranBookmark $b) => $this->presentBookmark($b, $corpus))
                ->all()
            : [];

        return Inertia::render('quran/index', [
            'surahs' => $corpus->surahs(),
            'bookmarks' => $bookmarks,
            'continue' => $bookmarks[0] ?? null,
        ]);
    }

    public function show(Request $request, int $surah, QuranCorpus $corpus, QuranTranslations $translations): Response
    {
        $meta = $corpus->surah($surah);
        abort_if($meta === null, 404);

        $code = $this->translationCode($request, $translations);

        return Inertia::render('quran/show', [
            'surah' => $meta,
            'ayat' => $corpus->ayat($surah),
            'basmala' => in_array($surah, [1, 9], true) ? null : $corpus->basmala(),
            'previous' => $corpus->surah($surah - 1),
            'next' => $corpus->surah($surah + 1),
            'translationCode' => $code,
            'translation' => fn () => $code === 'none' ? null : $translations->forSurah($code, $surah),
            'translations' => $translations->options(),
            'reciters' => QuranCorpus::RECITERS,
            'bookmarks' => fn () => $request->user()
                ? QuranBookmark::query()->where('user_id', $request->user()->id)
                    ->where('surah', $surah)->orderBy('ayah')
                    ->get(['id', 'ayah', 'note'])
                    ->map(fn (QuranBookmark $b) => ['id' => $b->id, 'ayah' => $b->ayah, 'note' => $b->note])
                    ->all()
                : [],
        ]);
    }

    /**
     * "?tr=en|fr|none" picks the translation and is remembered for the
     * session; otherwise the interface language, when a translation exists.
     */
    private function translationCode(Request $request, QuranTranslations $translations): string
    {
        $valid = fn (mixed $code) => is_string($code) && ($code === 'none' || $translations->has($code));

        $requested = $request->query('tr');
        if ($valid($requested)) {
            $request->session()->put('quran_translation', $requested);

            return $requested;
        }

        $remembered = $request->session()->get('quran_translation');
        if ($valid($remembered)) {
            return $remembered;
        }

        $locale = app()->getLocale();

        return $translations->has($locale) ? $locale : 'none';
    }

    /** @return array{id: int, surah: int, ayah: int, note: string|null, updated_at: string|null, name_en: string, name_ar: string} */
    private function presentBookmark(QuranBookmark $bookmark, QuranCorpus $corpus): array
    {
        $surah = $corpus->surah($bookmark->surah);

        return [
            'id' => $bookmark->id,
            'surah' => $bookmark->surah,
            'ayah' => $bookmark->ayah,
            'note' => $bookmark->note,
            'updated_at' => $bookmark->updated_at?->toIso8601String(),
            'name_en' => $surah['name_en'] ?? '',
            'name_ar' => $surah['name_ar'] ?? '',
        ];
    }
}
