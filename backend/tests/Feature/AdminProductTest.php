<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class AdminProductTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_create_product()
    {
        Storage::fake('public');
        $admin = User::factory()->create(['role' => 'admin']);
        $category = Category::factory()->create();

        $response = $this->actingAs($admin, 'sanctum')->postJson('/api/products', [
            'category_id' => $category->id,
            'name' => 'New Tech Gadget',
            'description' => 'Cool gadget',
            'price' => 299.99,
            'stock' => 50,
            'image' => UploadedFile::fake()->create('gadget.jpg', 100, 'image/jpeg'),
        ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('products', ['name' => 'New Tech Gadget']);

        $product = Product::where('name', 'New Tech Gadget')->first();
        $this->assertNotNull($product->image_path);
        Storage::disk('public')->assertExists($product->image_path);
    }

    public function test_admin_can_update_product()
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $product = Product::factory()->create();

        $response = $this->actingAs($admin, 'sanctum')->postJson("/api/products/{$product->id}", [
            'name' => 'Updated Product Name',
            'price' => 350.00,
        ]);

        $response->assertStatus(200);
        $this->assertDatabaseHas('products', [
            'id' => $product->id,
            'name' => 'Updated Product Name',
            'price' => 350.00,
        ]);
    }

    public function test_admin_can_delete_product()
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $product = Product::factory()->create();

        $response = $this->actingAs($admin, 'sanctum')->deleteJson("/api/products/{$product->id}");

        $response->assertStatus(200);
        $this->assertDatabaseMissing('products', ['id' => $product->id]);
    }

    public function test_customer_cannot_create_product()
    {
        $customer = User::factory()->create(['role' => 'customer']);
        $category = Category::factory()->create();

        $response = $this->actingAs($customer, 'sanctum')->postJson('/api/products', [
            'category_id' => $category->id,
            'name' => 'Should fail',
            'price' => 10,
            'stock' => 5,
        ]);

        $response->assertStatus(403);
    }

    public function test_customer_cannot_delete_product()
    {
        $customer = User::factory()->create(['role' => 'customer']);
        $product = Product::factory()->create();

        $response = $this->actingAs($customer, 'sanctum')->deleteJson("/api/products/{$product->id}");

        $response->assertStatus(403);
    }
}
