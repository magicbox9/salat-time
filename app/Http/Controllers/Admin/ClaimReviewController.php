<?php

namespace App\Http\Controllers\Admin;

use App\Models\Mosque;
use App\Models\MosqueClaim;
use App\Models\User;
use App\Notifications\ClaimApproved;
use App\Notifications\ClaimRejected;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Notifications\Notification;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;

/** An admin approves (the claimant becomes the mosque's owner) or rejects a claim. */
class ClaimReviewController extends AdminController
{
    public function approve(Request $request, MosqueClaim $claim): RedirectResponse
    {
        $data = $request->validate(
            ['note' => ['nullable', 'string', 'max:1000']],
            ['note.max' => ui('admin.v_note_max')],
        );
        /** @var User $admin */
        $admin = $request->user();

        $decided = $this->decide($claim, MosqueClaim::APPROVED, $admin, $data['note'] ?? null, function (MosqueClaim $locked) use ($admin) {
            // The claimant becomes the page's owner (an existing editor is promoted).
            $mosque = Mosque::query()->findOrFail($locked->mosque_id);
            $mosque->managers()->syncWithoutDetaching([
                $locked->user_id => ['role' => 'owner', 'granted_by' => $admin->id],
            ]);
        });

        if (! $decided) {
            return $this->alreadyDecided($claim);
        }

        $name = $this->notifyClaimant($decided, new ClaimApproved($decided));
        Inertia::flash('toast', ['type' => 'success', 'message' => ui('admin.claim_approved', ['name' => $name])]);

        return to_route('admin.claims.index');
    }

    public function reject(Request $request, MosqueClaim $claim): RedirectResponse
    {
        $data = $request->validate(
            ['note' => ['required', 'string', 'min:3', 'max:1000']],
            [
                'note.required' => ui('admin.v_note_required'),
                'note.min' => ui('admin.v_note_required'),
                'note.max' => ui('admin.v_note_max'),
            ],
        );
        /** @var User $admin */
        $admin = $request->user();

        $decided = $this->decide($claim, MosqueClaim::REJECTED, $admin, $data['note']);

        if (! $decided) {
            return $this->alreadyDecided($claim);
        }

        $name = $this->notifyClaimant($decided, new ClaimRejected($decided));
        Inertia::flash('toast', ['type' => 'success', 'message' => ui('admin.claim_rejected', ['name' => $name])]);

        return to_route('admin.claims.index');
    }

    /**
     * Records the decision once: the row is locked so two admins cannot both decide.
     * Returns null when the claim was no longer pending.
     */
    private function decide(MosqueClaim $claim, string $status, User $admin, ?string $note, ?callable $then = null): ?MosqueClaim
    {
        return DB::transaction(function () use ($claim, $status, $admin, $note, $then): ?MosqueClaim {
            $locked = MosqueClaim::query()->lockForUpdate()->find($claim->id);
            if (! $locked || $locked->status !== MosqueClaim::PENDING) {
                return null;
            }

            if ($then) {
                $then($locked);
            }

            $locked->forceFill([
                'status' => $status,
                'reviewed_by' => $admin->id,
                'reviewed_at' => now(),
                'review_note' => $note !== null && trim($note) !== '' ? trim($note) : null,
            ])->save();

            return $locked->load(['user', 'mosque']);
        });
    }

    private function alreadyDecided(MosqueClaim $claim): RedirectResponse
    {
        Inertia::flash('toast', ['type' => 'error', 'message' => ui('admin.claim_already_decided')]);

        return to_route('admin.claims.show', $claim);
    }

    /**
     * The claimant is written to in their own language (account setting, else the
     * app default). Returns their name for the confirmation message.
     */
    private function notifyClaimant(MosqueClaim $claim, Notification $notification): string
    {
        /** @var User $claimant */
        $claimant = $claim->getRelation('user');
        $claimant->notify($notification->locale($claimant->locale ?: config('app.locale')));

        return $claimant->name;
    }
}
