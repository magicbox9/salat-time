<?php

namespace App\Http\Controllers\Manage;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Manage\Support\ImageStore;
use App\Http\Controllers\MosquePage\Support\PostPresenter;
use App\Http\Requests\Manage\UpdateMosqueRequest;
use App\Models\Mosque;
use App\Support\MosquePresenter;
use Illuminate\Http\RedirectResponse;
use Inertia\Inertia;
use Inertia\Response;
use Throwable;

/** The page details a mosque's managers keep up to date. */
class MosqueSettingsController extends Controller
{
    public function edit(Mosque $mosque): Response
    {
        return Inertia::render('manage/edit', [
            'mosque' => [
                ...MosquePresenter::summary($mosque),
                'cover_url' => PostPresenter::url($mosque->cover_path),
            ],
            'values' => [
                'description' => $mosque->description ?? '',
                'association' => $mosque->association ?? '',
                'website' => $mosque->website ?? '',
                'phone' => $mosque->phone ?? '',
                'email' => $mosque->email ?? '',
                'jumua' => $mosque->jumua ?? '',
                'jumua2' => $mosque->jumua2 ?? '',
                'jumua3' => $mosque->jumua3 ?? '',
                'jumua_as_dhuhr' => (bool) $mosque->jumua_as_dhuhr,
            ],
        ]);
    }

    public function update(UpdateMosqueRequest $request, Mosque $mosque, ImageStore $images): RedirectResponse
    {
        $data = $request->safe()->only(UpdateMosqueRequest::FIELDS);
        if ($request->has('jumua_as_dhuhr')) {
            $data['jumua_as_dhuhr'] = $request->boolean('jumua_as_dhuhr');
        }

        $stored = [];
        $replaced = [];

        try {
            foreach (['logo' => ['logo_path', 512], 'cover' => ['cover_path', 2400]] as $field => [$column, $maxSide]) {
                if ($request->hasFile($field)) {
                    $data[$column] = $stored[] = $images->store($mosque, $request->file($field), $field, '', $maxSide);
                } elseif ($request->boolean("remove_$field")) {
                    $data[$column] = null;
                }
                if (array_key_exists($column, $data) && $mosque->{$column}) {
                    $replaced[] = $mosque->{$column};
                }
            }

            // Only the validated, manager-editable columns above are written.
            $mosque->fill($data)->save();
        } catch (Throwable $e) {
            // An unreadable second picture or a failed save leaves no orphan file behind.
            array_map(fn (string $path) => $images->delete($mosque, $path), $stored);

            throw $e;
        }

        // Old pictures go only once the new paths are saved.
        array_map(fn (string $path) => $images->delete($mosque, $path), $replaced);

        return Inertia::flash('toast', ['type' => 'success', 'message' => ui('manage.saved')])->back();
    }
}
