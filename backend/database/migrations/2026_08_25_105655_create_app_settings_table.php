<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('app_settings', function (Blueprint $table) {
            $table->id();
            $table->string('key')->unique();
            $table->text('value')->nullable();
            $table->timestamps();
        });

        // Initialize default settings
        \DB::table('app_settings')->insert([
            ['key' => 'primary_color', 'value' => 'blue'],
            ['key' => 'is_dark_mode', 'value' => 'false'],
            ['key' => 'featured_banner_url', 'value' => null],
            ['key' => 'featured_banner_title', 'value' => 'Welcome to CyberStore'],
        ]);
    }

    public function down(): void
    {
        Schema::dropIfExists('app_settings');
    }
};
