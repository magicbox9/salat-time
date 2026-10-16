<?php

namespace App\Http\Controllers\Claims;

use App\Http\Controllers\Controller;
use App\Models\MosqueClaim;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Streams a claim's supporting document from the private disk. Only platform
 * admins and the claimant pass the gate; the file is always an attachment.
 */
class ClaimDocumentController extends Controller
{
    public function __invoke(MosqueClaim $claim): StreamedResponse
    {
        Gate::authorize('view-claim-document', $claim);

        $path = $claim->document_path;
        $disk = Storage::disk('local');
        abort_if(
            $path === null || ! Str::startsWith($path, 'claims/'.$claim->id.'/') || ! $disk->exists($path),
            404,
        );

        $extension = Str::lower(pathinfo($path, PATHINFO_EXTENSION)) ?: 'bin';

        return $disk->download($path, 'claim-'.$claim->id.'-document.'.$extension, [
            'Cache-Control' => 'private, no-store',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }
}
