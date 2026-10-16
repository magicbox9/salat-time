<?php

namespace Database\Factories;

use App\Models\MosquePost;
use App\Models\PostComment;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<PostComment> */
class PostCommentFactory extends Factory
{
    public function definition(): array
    {
        return [
            'post_id' => MosquePost::factory(),
            'user_id' => User::factory(),
            'body' => fake()->sentence(),
        ];
    }
}
