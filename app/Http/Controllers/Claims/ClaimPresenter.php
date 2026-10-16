<?php

namespace App\Http\Controllers\Claims;

use App\Models\Mosque;
use App\Models\MosqueClaim;
use App\Models\User;
use DateTimeInterface;

/**
 * The claim fields sent to the React pages. The stored document path is never
 * exposed: pages only get a link to the authorised download route.
 */
class ClaimPresenter
{
    /** @return array<string, mixed> */
    public static function base(MosqueClaim $claim): array
    {
        $mosque = $claim->relationLoaded('mosque') ? $claim->getRelation('mosque') : null;

        return [
            'id' => $claim->id,
            'status' => $claim->status,
            'role_at_mosque' => $claim->role_at_mosque,
            'created_at' => self::iso($claim->created_at),
            'reviewed_at' => self::iso($claim->reviewed_at),
            'has_document' => $claim->document_path !== null,
            'document_url' => $claim->document_path !== null ? route('claims.document', $claim) : null,
            'mosque' => $mosque instanceof Mosque ? [
                'slug' => $mosque->slug,
                'name' => $mosque->name,
                'city' => $mosque->city,
                'verified' => $mosque->verified_at !== null,
            ] : null,
        ];
    }

    /**
     * What the claimant sees on /me/claims.
     *
     * @return array<string, mixed>
     */
    public static function forClaimant(MosqueClaim $claim): array
    {
        return [
            ...self::base($claim),
            'message' => $claim->message,
            'review_note' => $claim->review_note,
        ];
    }

    /**
     * A row of the admin review queue.
     *
     * @return array<string, mixed>
     */
    public static function forAdminList(MosqueClaim $claim): array
    {
        $user = $claim->relationLoaded('user') ? $claim->getRelation('user') : null;

        return [
            ...self::base($claim),
            'user' => $user instanceof User ? ['id' => $user->id, 'name' => $user->name, 'email' => $user->email] : null,
        ];
    }

    /**
     * Everything an admin needs to decide.
     *
     * @return array<string, mixed>
     */
    public static function forAdmin(MosqueClaim $claim): array
    {
        $reviewer = $claim->relationLoaded('reviewer') ? $claim->getRelation('reviewer') : null;

        return [
            ...self::forAdminList($claim),
            'phone' => $claim->phone,
            'message' => $claim->message,
            'review_note' => $claim->review_note,
            'reviewer' => $reviewer instanceof User ? ['id' => $reviewer->id, 'name' => $reviewer->name] : null,
        ];
    }

    /** An ISO 8601 date for the pages, or null. */
    public static function iso(mixed $value): ?string
    {
        return $value instanceof DateTimeInterface ? $value->format(DateTimeInterface::ATOM) : null;
    }
}
