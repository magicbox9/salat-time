<?php

namespace App\Http\Controllers\Claims;

use App\Http\Controllers\Controller;
use App\Models\Mosque;
use App\Models\MosqueClaim;
use App\Models\User;
use App\Notifications\ClaimSubmitted;
use App\Support\MosquePresenter;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;
use Inertia\Response;
use RuntimeException;

/** A signed-in, verified user asks to manage a mosque's page. */
class MosqueClaimController extends Controller
{
    /** Supporting document limit, in kilobytes (8 MB). */
    public const DOCUMENT_MAX_KB = 8192;

    public function create(Request $request, Mosque $mosque): Response
    {
        /** @var User $user */
        $user = $request->user();
        $pending = $this->pendingClaim($user, $mosque);

        return Inertia::render('claims/create', [
            'mosque' => MosquePresenter::summary($mosque->loadCount('calendars')),
            'manages' => $user->manages($mosque),
            'pendingClaim' => $pending ? [
                'id' => $pending->id,
                'created_at' => ClaimPresenter::iso($pending->created_at),
            ] : null,
            'documentMaxMb' => intdiv(self::DOCUMENT_MAX_KB, 1024),
        ]);
    }

    public function store(Request $request, Mosque $mosque): RedirectResponse
    {
        /** @var User $user */
        $user = $request->user();

        if ($user->manages($mosque)) {
            return $this->refuse(ui('claims.error_already_manager'));
        }
        if ($this->pendingClaim($user, $mosque)) {
            return $this->refuse(ui('claims.error_already_pending'));
        }

        $data = $request->validate([
            // One line of text: no control characters (line breaks, tabs) and no
            // bidirectional overrides that could disguise the role in the admin pages.
            'role_at_mosque' => ['required', 'string', 'max:120', 'not_regex:/[\p{Cc}\x{202A}-\x{202E}\x{2066}-\x{2069}]/u'],
            'phone' => ['nullable', 'string', 'max:40', 'regex:/^\+?[0-9 ().\-]{6,40}$/'],
            'message' => ['nullable', 'string', 'max:2000'],
            'document' => ['nullable', 'file', 'mimes:pdf,jpg,jpeg,png', 'mimetypes:application/pdf,image/jpeg,image/png',
                'max:'.self::DOCUMENT_MAX_KB],
        ], [
            'role_at_mosque.required' => ui('claims.v_role_required'),
            'role_at_mosque.string' => ui('claims.v_role_required'),
            'role_at_mosque.max' => ui('claims.v_role_max'),
            'role_at_mosque.not_regex' => ui('claims.v_role_invalid'),
            'phone.string' => ui('claims.v_phone'),
            'phone.max' => ui('claims.v_phone'),
            'phone.regex' => ui('claims.v_phone'),
            'message.max' => ui('claims.v_message_max'),
            'document.file' => ui('claims.v_document_type'),
            'document.uploaded' => ui('claims.v_document_size'),
            'document.mimes' => ui('claims.v_document_type'),
            'document.mimetypes' => ui('claims.v_document_type'),
            'document.max' => ui('claims.v_document_size'),
        ]);

        try {
            $claim = DB::transaction(function () use ($user, $mosque, $data, $request): MosqueClaim {
                $claim = MosqueClaim::query()->create([
                    'mosque_id' => $mosque->id,
                    'user_id' => $user->id,
                    'status' => MosqueClaim::PENDING,
                    'role_at_mosque' => trim($data['role_at_mosque']),
                    'phone' => isset($data['phone']) ? trim($data['phone']) : null,
                    'message' => isset($data['message']) ? trim($data['message']) : null,
                ]);

                $file = $request->file('document');
                if ($file instanceof UploadedFile) {
                    // Private disk (storage/app/private): only the download controller serves it.
                    $path = $file->store('claims/'.$claim->id, 'local');
                    if ($path === false) {
                        throw new RuntimeException('The claim document could not be stored.');
                    }
                    $claim->forceFill(['document_path' => $path])->save();
                }

                return $claim;
            });
        } catch (UniqueConstraintViolationException) {
            // Two submissions at once: the partial unique index keeps a single pending claim.
            return $this->refuse(ui('claims.error_already_pending'));
        }

        $this->notifyAdmins($claim);

        Inertia::flash('toast', ['type' => 'success', 'message' => ui('claims.submitted')]);

        return to_route('claims.mine');
    }

    private function pendingClaim(User $user, Mosque $mosque): ?MosqueClaim
    {
        return MosqueClaim::query()
            ->where('mosque_id', $mosque->id)
            ->where('user_id', $user->id)
            ->where('status', MosqueClaim::PENDING)
            ->first(['id', 'created_at']);
    }

    private function refuse(string $message): RedirectResponse
    {
        Inertia::flash('toast', ['type' => 'error', 'message' => $message]);

        return to_route('claims.mine');
    }

    /** Each admin is told in their own language. */
    private function notifyAdmins(MosqueClaim $claim): void
    {
        User::query()
            ->where('is_admin', true)
            ->whereNotNull('email_verified_at')
            ->get(['id', 'name', 'email', 'locale'])
            ->each(fn (User $admin) => $admin->notify(
                (new ClaimSubmitted($claim))->locale($admin->locale ?: config('app.locale')),
            ));
    }
}
