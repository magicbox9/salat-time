# Salat Time Web — guide for AI agents and developers

The web version of Salat Time: prayer times for every mosque, a 3D globe to find
them, mosque pages (news, comments), adhkar, the Qur'an, and a personal prayer
tracker scored in hasanat. Mosques can request to manage their page.

This folder is the `web-app` branch of `magicbox9/salat-time`. Like `mac_os/`
(branch `main`) and `windows/` (branch `windows-app`), it shares no code with
the other platforms.

## Run it

PHP only runs in Docker; Node runs on the host.

```bash
docker compose up -d                          # nginx, app, queue, scheduler, db, redis, mail, adminer
docker compose exec app php artisan <cmd>     # artisan, composer, tests
docker compose exec app php artisan test      # PHPUnit, against PostgreSQL db "salat_testing"
docker compose exec app php artisan mosques:import   # load the studied mosques (see below)
npm run build                                 # frontend (Vite); npm run dev for hot reload
```

App: http://localhost:8095 · test inbox (Mailpit): http://localhost:8026 ·
database browser: http://localhost:8086 · Postgres: localhost:5434.

## Stack

Laravel 13 (PHP 8.4, Fortify auth with email verification, 2FA, passkeys),
Inertia 3 + React 19 + TypeScript + Tailwind 4 (starter kit components in
`resources/js/components/ui`), PostgreSQL 17 (pg_trgm, unaccent, earthdistance),
Redis (cache, sessions, queue), MapLibre GL for the globe and maps.

## Invariants (never break these)

1. **Trust is server-side.** Roles and mosque management rights come from the
   database (`users.is_admin`, `mosque_managers`), checked with policies — never
   from the request.
2. **Schema changes only in new migrations**, with foreign keys and explicit
   `ON DELETE`. Never edit a committed migration.
3. **Prayer times come from published mosque calendars** (Mawaqit data imported
   from the research studies) until the automatic calculation lands. Never
   invent or estimate a mosque's times; show "no published times" instead.
4. **No calls to mawaqit.net** unless `MAWAQIT_SYNC_ENABLED=true` was set by the
   owner. Mawaqit describes its API as private; the imported data is subject to
   its terms. Before going public, the owner must clear data use with Mawaqit.
5. **Qur'an text is never edited or regenerated.** `resources/quran/` holds the
   verified KFGQPC corpus copied unchanged from the Mac app's `QuranAssets`
   (same SHA-256). Recitation audio streams only after the user presses play.
6. **Money never passes through the platform.** Donations go straight to the
   mosque: PayPal Checkout with the mosque's own verified PayPal account as the
   payee, or a bank transfer to the mosque's verified IBAN (the mosque confirms
   receipt). Only verified mosques with a verified payout method can publish a
   campaign, and an admin approves each campaign. IBANs are encrypted at rest.
   PayPal stays in sandbox until the owner sets live credentials.
7. **Hasanat are encouragement, not a judgement.** Keep the wording humble
   ("Allah alone knows the true reward").
8. **Markdown from managers** (pages, khutbahs, campaign stories) is rendered on
   the server with `App\Support\Markdown::toHtml` and shown only through
   `<MarkdownContent>`. No other `dangerouslySetInnerHTML`.
9. **Religious texts on screens** (ayat, hadith, adhkar) come only from the
   verified files in `resources/quran` and `resources/content`, or are typed by
   the mosque itself. Never write them from memory.

## Working rules

- Conventional Commits (`feat(web): …`, `fix(mosques): …`), one concern per
  commit, explicit-path staging. Commit after every step.
- Ship tests with every feature: allowed user, denied user, validation.
- Files under ~300 lines; extract before growing a big file.
- Strings go through the translation files (`lang/en.json`, `lang/fr.json`,
  `lang/ar.json`); Arabic switches the layout to right-to-left.
- Check UI changes in a browser in light and dark mode, at phone and desktop widths.
