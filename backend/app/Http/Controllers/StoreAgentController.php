<?php

namespace App\Http\Controllers;

use App\Models\AppSetting;
use App\Models\Product;
use App\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

class StoreAgentController extends Controller
{
    public static function getToolDefinitions()
    {
        return [
            [
                'name' => 'change_theme',
                'description' => 'Changes the global theme color of the app.',
                'parameters' => [
                    'type' => 'object',
                    'properties' => [
                        'color' => [
                            'type' => 'string',
                            'description' => 'The color name (red, blue, purple, green, orange).'
                        ],
                        'is_dark' => [
                            'type' => 'boolean',
                            'description' => 'Whether to enable dark mode.'
                        ]
                    ],
                    'required' => ['color']
                ]
            ],
            [
                'name' => 'add_product',
                'description' => 'Adds a new product to the store inventory.',
                'parameters' => [
                    'type' => 'object',
                    'properties' => [
                        'name' => ['type' => 'string'],
                        'price' => ['type' => 'number'],
                        'category_name' => ['type' => 'string'],
                        'description' => ['type' => 'string'],
                        'stock' => ['type' => 'integer'],
                        'image_url' => ['type' => 'string', 'description' => 'Optional URL for the product image.']
                    ],
                    'required' => ['name', 'price', 'category_name']
                ]
            ],
            [
                'name' => 'set_home_banner',
                'description' => 'Sets a featured image banner and title on the customer home screen.',
                'parameters' => [
                    'type' => 'object',
                    'properties' => [
                        'image_url' => ['type' => 'string', 'description' => 'URL of the banner image.'],
                        'title' => ['type' => 'string', 'description' => 'Headline text for the banner.']
                    ],
                    'required' => ['image_url']
                ]
            ],
            [
                'name' => 'update_product_stock',
                'description' => 'Updates the available stock count for an existing product.',
                'parameters' => [
                    'type' => 'object',
                    'properties' => [
                        'product_id' => ['type' => 'integer'],
                        'new_stock' => ['type' => 'integer']
                    ],
                    'required' => ['product_id', 'new_stock']
                ]
            ],
            [
                'name' => 'set_featured_product',
                'description' => 'Marks a product as featured so it appears at the top of the list.',
                'parameters' => [
                    'type' => 'object',
                    'properties' => [
                        'product_id' => ['type' => 'integer'],
                        'is_featured' => ['type' => 'boolean']
                    ],
                    'required' => ['product_id', 'is_featured']
                ]
            ],
            [
                'name' => 'update_product_price',
                'description' => 'Changes the price of an existing product.',
                'parameters' => [
                    'type' => 'object',
                    'properties' => [
                        'product_id' => ['type' => 'integer'],
                        'new_price' => ['type' => 'number']
                    ],
                    'required' => ['product_id', 'new_price']
                ]
            ],
            [
                'name' => 'send_broadcast_notification',
                'description' => 'Sends a promotional push notification to all registered customers.',
                'parameters' => [
                    'type' => 'object',
                    'properties' => [
                        'title' => ['type' => 'string'],
                        'message' => ['type' => 'string']
                    ],
                    'required' => ['title', 'message']
                ]
            ]
        ];
    }

    public function executeTool(Request $request)
    {
        $toolName = $request->input('name');
        $args = $request->input('args');

        Log::info("AI Executing Tool: $toolName", (array)$args);

        try {
            switch ($toolName) {
                case 'change_theme':
                    AppSetting::updateOrCreate(['key' => 'primary_color'], ['value' => $args['color']]);
                    if (isset($args['is_dark'])) {
                        AppSetting::updateOrCreate(['key' => 'is_dark_mode'], ['value' => $args['is_dark'] ? 'true' : 'false']);
                    }
                    \Cache::forget('app_settings_global');
                    return ['status' => 'success', 'message' => "Theme changed to {$args['color']}"];

                case 'add_product':
                    $category = Category::firstOrCreate(['name' => $args['category_name']]);
                    if ($category->wasRecentlyCreated) \Cache::forget('categories_all');

                    $productData = [
                        'name' => $args['name'],
                        'price' => $args['price'],
                        'category_id' => $category->id,
                        'description' => $args['description'] ?? '',
                        'stock' => $args['stock'] ?? 10,
                    ];

                    if (isset($args['image_url'])) {
                        try {
                            $imageContent = @file_get_contents($args['image_url']);
                            if ($imageContent) {
                                $filename = 'ai_' . time() . '.jpg';
                                $path = 'products/' . $filename;
                                Storage::disk('public')->put($path, $imageContent);
                                $productData['image_path'] = $path;
                            }
                        } catch (\Exception $e) { Log::error("AI Image Download Fail: " . $e->getMessage()); }
                    }

                    $product = Product::create($productData);
                    return ['status' => 'success', 'message' => "Product '{$product->name}' added."];

                case 'set_home_banner':
                    AppSetting::updateOrCreate(['key' => 'featured_banner_url'], ['value' => $args['image_url']]);
                    if (isset($args['title'])) {
                        AppSetting::updateOrCreate(['key' => 'featured_banner_title'], ['value' => $args['title']]);
                    }
                    \Cache::forget('app_settings_global');
                    return ['status' => 'success', 'message' => "Home banner updated."];

                case 'update_product_stock':
                    $product = Product::find($args['product_id']);
                    if (!$product) return ['status' => 'error', 'message' => 'Product not found.'];
                    $product->stock = $args['new_stock'];
                    $product->save();
                    return ['status' => 'success', 'message' => "Stock for '{$product->name}' updated to {$args['new_stock']}."];

                case 'set_featured_product':
                    $product = Product::find($args['product_id']);
                    if (!$product) return ['status' => 'error', 'message' => 'Product not found.'];
                    $product->is_featured = $args['is_featured'];
                    $product->save();
                    $msg = $args['is_featured'] ? "featured" : "unfeatured";
                    return ['status' => 'success', 'message' => "Product '{$product->name}' is now $msg."];

                case 'update_product_price':
                    $product = Product::find($args['product_id']);
                    if (!$product) return ['status' => 'error', 'message' => 'Product not found.'];
                    $old = $product->price;
                    $product->price = $args['new_price'];
                    $product->save();
                    return ['status' => 'success', 'message' => "Price for '{$product->name}' updated from $old to {$args['new_price']} ETB."];

                case 'send_broadcast_notification':
                    $ns = new \App\Services\NotificationService();
                    $count = $ns->sendToAll($args['title'], $args['message']);
                    return ['status' => 'success', 'message' => "Broadcast sent to $count users."];

                default:
                    return ['status' => 'error', 'message' => "Unknown command: $toolName"];
            }
        } catch (\Exception $e) {
            Log::error("Tool Execution Error ($toolName): " . $e->getMessage());
            return ['status' => 'error', 'message' => "Command failed: " . $e->getMessage()];
        }
    }

    public function getSettings()
    {
        $settings = \Cache::remember('app_settings_global', 3600, function () {
            return AppSetting::all()->pluck('value', 'key');
        });
        return response()->json($settings);
    }
}
