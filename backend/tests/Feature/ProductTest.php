<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Product;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ProductTest extends TestCase
{
    use RefreshDatabase;

    public function test_can_list_products()
    {
        Product::factory()->count(3)->create();

        $response = $this->getJson('/api/products');

        $response->assertStatus(200)
            ->assertJsonCount(3);
    }

    public function test_can_filter_products_by_category()
    {
        $cat1 = Category::factory()->create();
        $cat2 = Category::factory()->create();

        Product::factory()->create(['category_id' => $cat1->id]);
        Product::factory()->create(['category_id' => $cat2->id]);

        $response = $this->getJson("/api/products?category_id={$cat1->id}");

        $response->assertStatus(200)
            ->assertJsonCount(1)
            ->assertJsonFragment(['category_id' => $cat1->id]);
    }

    public function test_can_search_products_by_name()
    {
        Product::factory()->create(['name' => 'Special Keyboard']);
        Product::factory()->create(['name' => 'Mouse Pad']);

        $response = $this->getJson("/api/products?search=Keyboard");

        $response->assertStatus(200)
            ->assertJsonCount(1)
            ->assertJsonFragment(['name' => 'Special Keyboard']);
    }

    public function test_can_show_single_product()
    {
        $product = Product::factory()->create();

        $response = $this->getJson("/api/products/{$product->id}");

        $response->assertStatus(200)
            ->assertJson(['id' => $product->id, 'name' => $product->name]);
    }
}
