<?php

namespace Tests\Unit;

use App\Models\CartItem;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CartLogicTest extends TestCase
{
    use RefreshDatabase;

    public function test_cart_total_calculation()
    {
        $user = User::factory()->create();

        $p1 = Product::factory()->create(['price' => 100.00]);
        $p2 = Product::factory()->create(['price' => 50.00]);

        CartItem::factory()->create([
            'user_id' => $user->id,
            'product_id' => $p1->id,
            'quantity' => 2,
        ]);

        CartItem::factory()->create([
            'user_id' => $user->id,
            'product_id' => $p2->id,
            'quantity' => 3,
        ]);

        // Total should be (100 * 2) + (50 * 3) = 200 + 150 = 350
        $this->assertEquals(350.00, $user->cart_total);
    }

    public function test_empty_cart_total_is_zero()
    {
        $user = User::factory()->create();
        $this->assertEquals(0.00, $user->cart_total);
    }
}
