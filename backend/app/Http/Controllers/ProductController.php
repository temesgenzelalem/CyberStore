<?php

namespace App\Http\Controllers;

use App\Models\Product;
use App\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Log;

class ProductController extends Controller
{
    public function index(Request $request)
    {
        try {
            $query = Product::select(['id', 'category_id', 'name', 'price', 'image_path', 'is_featured', 'rating', 'review_count'])
                ->with('category:id,name')
                ->orderBy('is_featured', 'desc')
                ->orderBy('created_at', 'desc');

            if ($request->has('category_id')) {
                $query->where('category_id', $request->category_id);
            }

            if ($request->has('search')) {
                $query->where('name', 'like', '%' . $request->search . '%');
            }

            return response()->json($query->get());
        } catch (\Exception $e) {
            Log::error('Product Index Error: ' . $e->getMessage());
            return response()->json(['message' => 'Error loading products'], 500);
        }
    }

    public function categories()
    {
        return \Cache::remember('categories_all', 3600, function () {
            return Category::all();
        });
    }

    public function show($id)
    {
        return response()->json(Product::with('category')->findOrFail($id));
    }

    public function store(Request $request)
    {
        Log::info('Attempting to store product', $request->except('image'));

        try {
            $request->validate([
                'category_id' => 'required|exists:categories,id',
                'name' => 'required|string|max:255',
                'description' => 'nullable|string',
                'price' => 'required|numeric',
                'stock' => 'required|integer',
                'image' => 'nullable|image|mimes:jpeg,png,jpg,gif|max:10240', // Increased to 10MB
            ]);

            $data = $request->except('image');

            if ($request->hasFile('image')) {
                $file = $request->file('image');
                $filename = time() . '_' . $file->getClientOriginalName();

                // CRITICAL: Simple store first to ensure success
                $path = $file->storeAs('products', $filename, 'public');
                Log::info('Image saved to: ' . $path);

                // OPTIONAL: Try compression, but don't fail if it doesn't work
                try {
                    if (class_exists('\Intervention\Image\ImageManager')) {
                        $manager = new \Intervention\Image\ImageManager(new \Intervention\Image\Drivers\Gd\Driver());
                        $fullPath = Storage::disk('public')->path($path);
                        $image = $manager->read($fullPath);
                        $image->scale(width: 800);
                        Storage::disk('public')->put($path, (string) $image->toJpeg(75));
                        Log::info('Image compressed successfully.');
                    }
                } catch (\Exception $e) {
                    Log::warning('Compression failed, keeping original: ' . $e->getMessage());
                }

                $data['image_path'] = $path;
            }

            $product = Product::create($data);
            Log::info('Product created successfully ID: ' . $product->id);
            return response()->json($product, 201);

        } catch (\Illuminate\Validation\ValidationException $ve) {
            return response()->json(['message' => 'Validation Error', 'errors' => $ve->errors()], 422);
        } catch (\Exception $e) {
            Log::error('Product Store Fatal Error: ' . $e->getMessage());
            return response()->json(['message' => 'Internal Server Error: ' . $e->getMessage()], 500);
        }
    }

    public function update(Request $request, $id)
    {
        $product = Product::findOrFail($id);

        try {
            $request->validate([
                'category_id' => 'sometimes|exists:categories,id',
                'name' => 'sometimes|string|max:255',
                'description' => 'nullable|string',
                'price' => 'sometimes|numeric',
                'stock' => 'sometimes|integer',
                'image' => 'nullable|image|mimes:jpeg,png,jpg,gif|max:5120',
            ]);

            $data = $request->except('image');

            if ($request->hasFile('image')) {
                if ($product->image_path) {
                    Storage::disk('public')->delete($product->image_path);
                }

                $file = $request->file('image');
                $filename = time() . '_' . $file->getClientOriginalName();
                $path = $file->storeAs('products', $filename, 'public');

                try {
                    if (class_exists('\Intervention\Image\ImageManager')) {
                        $manager = new \Intervention\Image\ImageManager(new \Intervention\Image\Drivers\Gd\Driver());
                        $image = $manager->read(Storage::disk('public')->path($path));
                        $image->scale(width: 800);
                        Storage::disk('public')->put($path, (string) $image->toJpeg(75));
                    }
                } catch (\Exception $e) {
                    Log::warning('Update compression failed: ' . $e->getMessage());
                }
                $data['image_path'] = $path;
            }

            $product->update($data);
            return response()->json($product);
        } catch (\Exception $e) {
            return response()->json(['message' => 'Update failed: ' . $e->getMessage()], 500);
        }
    }

    public function destroy($id)
    {
        $product = Product::findOrFail($id);
        if ($product->image_path) {
            Storage::disk('public')->delete($product->image_path);
        }
        $product->delete();

        return response()->json(['message' => 'Product deleted successfully']);
    }
}
