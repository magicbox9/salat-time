<?php

namespace Tests\Feature\I18n;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Inertia\Testing\AssertableInertia as Assert;
use Laravel\Fortify\Features;
use Tests\TestCase;

/** Sign-in and settings screens speak the visitor's language (session "locale"). */
class LocalizedAuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_empty_login_shows_french_validation_errors()
    {
        $this->withSession(['locale' => 'fr'])
            ->from(route('login'))
            ->post(route('login.store'), [])
            ->assertSessionHasErrors([
                'email' => 'Le champ adresse e-mail est obligatoire.',
                'password' => 'Le champ mot de passe est obligatoire.',
            ]);
    }

    public function test_empty_login_shows_arabic_validation_errors()
    {
        $this->withSession(['locale' => 'ar'])
            ->from(route('login'))
            ->post(route('login.store'), [])
            ->assertSessionHasErrors([
                'email' => 'حقل البريد الإلكتروني مطلوب.',
                'password' => 'حقل كلمة المرور مطلوب.',
            ]);
    }

    public function test_english_stays_the_default()
    {
        $this->from(route('login'))
            ->post(route('login.store'), [])
            ->assertSessionHasErrors(['email' => 'The email field is required.']);
    }

    public function test_wrong_credentials_are_reported_in_french()
    {
        $user = User::factory()->create();

        $this->withSession(['locale' => 'fr'])
            ->from(route('login'))
            ->post(route('login.store'), ['email' => $user->email, 'password' => 'wrong-password'])
            ->assertSessionHasErrors(['email' => 'Ces identifiants ne correspondent à aucun compte.']);

        $this->assertGuest();
    }

    public function test_password_reset_link_status_is_in_arabic()
    {
        $this->skipUnlessFortifyHas(Features::resetPasswords());
        Notification::fake();
        $user = User::factory()->create();

        $this->withSession(['locale' => 'ar'])
            ->from(route('password.request'))
            ->post(route('password.email'), ['email' => $user->email])
            ->assertSessionHas('status', 'أرسلنا رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني.');
    }

    public function test_login_page_shares_arabic_strings_and_right_to_left_direction()
    {
        $this->withSession(['locale' => 'ar'])
            ->get(route('login'))
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('auth/login')
                ->where('locale', 'ar')
                ->where('dir', 'rtl')
                ->where('ui', fn ($ui) => $ui['auth.login_title'] === 'سجّل الدخول إلى حسابك'
                    && $ui['auth.login_button'] === 'تسجيل الدخول'));
    }

    public function test_profile_settings_share_french_strings()
    {
        $user = User::factory()->create();

        $this->actingAs($user)
            ->withSession(['locale' => 'fr'])
            ->get(route('profile.edit'))
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('settings/profile')
                ->where('dir', 'ltr')
                ->where('ui', fn ($ui) => $ui['settings.profile_title'] === 'Paramètres du profil'
                    && $ui['settings.delete_button'] === 'Supprimer le compte'));
    }

    public function test_profile_update_validation_is_in_french()
    {
        $user = User::factory()->create();

        $this->actingAs($user)
            ->withSession(['locale' => 'fr'])
            ->from(route('profile.edit'))
            ->patch(route('profile.update'), ['name' => '', 'email' => 'not-an-email'])
            ->assertSessionHasErrors([
                'name' => 'Le champ nom est obligatoire.',
                'email' => 'Le champ adresse e-mail doit être une adresse e-mail valide.',
            ]);
    }
}
