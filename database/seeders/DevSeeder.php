<?php

namespace Database\Seeders;

use App\Models\Campaign;
use App\Models\Donation;
use App\Models\Mosque;
use App\Models\MosquePage;
use App\Models\MosquePayoutMethod;
use App\Models\MosquePost;
use App\Models\User;
use App\Services\Fundraising\DonationLedger;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use RuntimeException;

/**
 * Local development accounts and sample content (never in production):
 *   admin@salat-time.test    platform admin
 *   manager@salat-time.test  manages Mosquée El Houda (Villefranche-sur-Saône)
 *   user@salat-time.test     a visitor whose own mosque is El Houda
 * Password for all three: "salat-dev-2026"
 *
 *   docker compose exec app php artisan db:seed --class=DevSeeder
 */
class DevSeeder extends Seeder
{
    private const PASSWORD = 'salat-dev-2026';

    public function run(): void
    {
        if (! app()->environment('local', 'testing')) {
            throw new RuntimeException('DevSeeder only runs in local development.');
        }

        $mosque = Mosque::query()->where('mawaqit_slug', 'mosquee-el-houda-villefranche-sur-saone')->first()
            ?? Mosque::query()->has('calendars')->firstOrFail();

        $admin = $this->user('admin@salat-time.test', 'Admin Salat Time', 'fr');
        $admin->forceFill(['is_admin' => true])->save();

        $manager = $this->user('manager@salat-time.test', 'Karim (El Houda)', 'fr');
        $manager->managedMosques()->syncWithoutDetaching([$mosque->id => ['role' => 'owner', 'granted_by' => $admin->id]]);

        $user = $this->user('user@salat-time.test', 'Yasmine', 'fr');
        $user->favoriteMosques()->syncWithoutDetaching([$mosque->id => ['is_primary' => true]]);

        $this->siteAndCampaign($mosque, $manager, $admin);

        if (! $mosque->posts()->exists()) {
            MosquePost::query()->create([
                'mosque_id' => $mosque->id,
                'author_id' => $manager->id,
                'type' => 'announcement',
                'title' => 'Bienvenue sur notre nouvelle page',
                'body' => "Retrouvez ici les horaires, les annonces et les activités de la mosquée.\nQu'Allah vous récompense.",
                'pinned' => true,
                'published_at' => now(),
            ]);
            MosquePost::query()->create([
                'mosque_id' => $mosque->id,
                'author_id' => $manager->id,
                'type' => 'event',
                'title' => 'Cours de tajwid pour adultes',
                'body' => 'Chaque samedi après la prière de Asr, inscription à l’accueil.',
                'event_starts_at' => now()->next('Saturday')->setTime(17, 0),
                'published_at' => now(),
            ]);
        }
    }

    /** A verified mosque with a bank account, an About page and a running campaign. */
    private function siteAndCampaign(Mosque $mosque, User $manager, User $admin): void
    {
        $mosque->forceFill(['verified_at' => $mosque->verified_at ?? now(), 'tagline' => 'Une mosquée ouverte à tous, au cœur de Villefranche'])->save();

        $bank = MosquePayoutMethod::query()->firstOrNew(['mosque_id' => $mosque->id, 'type' => 'bank']);
        $bank->fill([
            'account_holder' => "Association d'Orientation Islamique",
            // Public example IBAN (not a real account).
            'iban' => 'FR7630006000011234567890189',
            'bic' => 'AGRIFRPP',
            'bank_name' => 'Banque exemple',
        ]);
        $bank->forceFill(['verified_at' => now(), 'verified_by' => $admin->id])->save();

        MosquePage::query()->firstOrCreate(['mosque_id' => $mosque->id, 'slug' => 'a-propos'], [
            'author_id' => $manager->id,
            'title' => 'À propos',
            'body' => "## Notre mosquée\n\nLa mosquée El Houda accueille les fidèles pour les cinq prières, la prière du vendredi et les cours.\n\n- Cours de Coran pour enfants le mercredi\n- Cours de tajwid pour adultes le samedi",
            'show_in_menu' => true,
            'published_at' => now(),
        ]);

        $campaign = Campaign::withTrashed()->where('slug', 'renovation-salle-des-ablutions')->first();
        if (! $campaign) {
            $campaign = Campaign::query()->create([
                'mosque_id' => $mosque->id,
                'created_by' => $manager->id,
                'slug' => 'renovation-salle-des-ablutions',
                'kind' => 'building',
                'title' => 'Rénovation de la salle des ablutions',
                'summary' => 'Remplacer la plomberie, les sols et ajouter un accès pour les personnes à mobilité réduite.',
                'story' => "## Le projet\n\nNotre salle des ablutions date de 1998. Nous voulons la rénover entièrement : plomberie, sols antidérapants et un accès adapté.\n\n## Le budget\n\n- Plomberie : 18 000 €\n- Sols : 12 000 €\n- Accessibilité : 10 000 €",
                'currency' => 'EUR',
                'goal_amount' => 4_000_000,
                'allow_paypal' => true,
                'allow_bank' => true,
                'show_donor_names' => true,
                'starts_at' => now()->subDays(10),
                'ends_at' => now()->addDays(50),
            ]);
            $campaign->forceFill(['status' => 'active', 'reviewed_by' => $admin->id, 'reviewed_at' => now()])->save();
            foreach ([[15000, 'Samir', false], [5000, 'Fatima', false], [100000, null, true], [2500, 'Omar', false]] as $i => [$amount, $name, $anonymous]) {
                $donation = Donation::query()->create([
                    'campaign_id' => $campaign->id, 'mosque_id' => $mosque->id, 'donor_name' => $name, 'anonymous' => $anonymous,
                    'amount' => $amount, 'currency' => 'EUR', 'method' => 'bank', 'reference' => 'ST-DEMO-'.($i + 1),
                    'message' => $i === 0 ? 'Qu’Allah facilite ce projet.' : null,
                ]);
                app(DonationLedger::class)->complete($donation);
            }
        }
    }

    private function user(string $email, string $name, string $locale): User
    {
        $user = User::query()->firstOrNew(['email' => $email]);
        $user->forceFill([
            'name' => $name,
            'password' => Hash::make(self::PASSWORD),
            'email_verified_at' => now(),
            'locale' => $locale,
        ])->save();

        return $user;
    }
}
