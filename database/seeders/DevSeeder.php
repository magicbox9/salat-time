<?php

namespace Database\Seeders;

use App\Models\Mosque;
use App\Models\MosquePost;
use App\Models\User;
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
