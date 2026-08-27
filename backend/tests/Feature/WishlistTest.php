<?php

namespace Tests\Feature;

use App\Models\Product;
use App\Models\User;
use App\Models\WishlistItem;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class WishlistTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_add_to_wishlist()
    {
        $user = User::factory()->create();
        $product = Product::factory()->create();

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/wishlist', [
            'product_id' => $product->id,
        ]);

        $response->assertStatus(200);
        $this->assertDatabaseHas('wishlist_items', [
            'user_id' => $user->id,
            'product_id' => $product->id,
        ]);
    }

    public function test_user_can_view_wishlist()
    {
        $user = User::factory()->create();
        WishlistItem::factory()->count(2)->create(['user_id' => $user->id]);

        $response = $this->actingAs($user, 'sanctum')->getJson('/api/wishlist');

        $response->assertStatus(200)
            ->assertJsonCount(2);
    }

    public function test_user_can_remove_from_wishlist()
    {
        $user = User::factory()->create();
        $wishlistItem = WishlistItem::factory()->create(['user_id' => $user->id]);

        $response = $this->actingAs($user, 'sanctum')->deleteJson("/api/wishlist/{$wishlistItem->id}");

        $response->assertStatus(200);
        $this->assertDatabaseMissing('wishlist_items', ['id' => $wishlistItem->id]);
    }
}
