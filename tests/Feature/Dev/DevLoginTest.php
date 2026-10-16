<?php

namespace Tests\Feature\Dev;

use Tests\TestCase;

class DevLoginTest extends TestCase
{
    public function test_quick_login_does_not_exist_outside_local_development(): void
    {
        $this->post('/dev-login/admin')->assertNotFound();
        $this->get('/login')->assertInertia(fn ($page) => $page->where('devAccounts', []));
    }
}
