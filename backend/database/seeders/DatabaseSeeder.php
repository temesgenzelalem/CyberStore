<?php

namespace Database\Seeders;

use App\Models\User;
use App\Models\Category;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // Default Admin
        User::create([
            'name' => 'Admin User',
            'email' => 'admin@cypher.com',
            'password' => Hash::make('12345678'),
            'role' => 'admin',
        ]);

        // Sample Categories
        $categories = [
            ['name' => 'Electronics', 'icon_url' => 'https://example.com/icons/electronics.png'],
            ['name' => 'Fashion', 'icon_url' => 'https://example.com/icons/fashion.png'],
            ['name' => 'Home', 'icon_url' => 'https://example.com/icons/home.png'],
            ['name' => 'Beauty', 'icon_url' => 'https://example.com/icons/beauty.png'],
        ];

        foreach ($categories as $category) {
            Category::create($category);
        }
    }
}
