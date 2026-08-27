<?php

namespace App\Http\Controllers;

use App\Models\Product;
use App\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class ProductController extends Controller
{
    public function index(Request $request)
    {
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
        // Admin only check should be in middleware
        $request->validate([
            'category_id' => 'required|exists:categories,id',
            'name' => 'required|string|max:255',
            'description' => 'nullable|string',
            'price' => 'required|numeric',
            'stock' => 'required|integer',
            'image' => 'nullable|image|mimes:jpeg,png,jpg,gif|max:2048',
        ]);

        $data = $request->except('image');

        if ($request->hasFile('image')) {
            $file = $request->file('image');
            try {
                $manager = new \Intervention\Image\ImageManager(new \Intervention\Image\Drivers\Gd\Driver());
                $image = $manager->read($file);
                $image->scale(width: 800);

                $path = 'products/' . $file->hashName();
                Storage::disk('public')->put($path, (string) $image->toJpeg(80));
            } catch (\Exception $e) {
                \Illuminate\Support\Facades\Log::warning('Image compression failed, using original: ' . $e->getMessage());
                $path = $file->store('products', 'public');
            }
            $data['image_path'] = $path;
        }

        $product = Product::create($data);

        return response()->json($product, 201);
    }

    public function update(Request $request, $id)
    {
        $product = Product::findOrFail($id);

        $request->validate([
            'category_id' => 'sometimes|exists:categories,id',
            'name' => 'sometimes|string|max:255',
            'description' => 'nullable|string',
            'price' => 'sometimes|numeric',
            'stock' => 'sometimes|integer',
            'image' => 'nullable|image|mimes:jpeg,png,jpg,gif|max:2048',
        ]);

        $data = $request->except('image');

        if ($request->hasFile('image')) {
            // Delete old image
            if ($product->image_path) {
                Storage::disk('public')->delete($product->image_path);
            }

            $file = $request->file('image');
            try {
                $manager = new \Intervention\Image\ImageManager(new \Intervention\Image\Drivers\Gd\Driver());
                $image = $manager->read($file);
                $image->scale(width: 800);

                $path = 'products/' . $file->hashName();
                Storage::disk('public')->put($path, (string) $image->toJpeg(80));
            } catch (\Exception $e) {
                \Illuminate\Support\Facades\Log::warning('Image compression failed, using original: ' . $e->getMessage());
                $path = $file->store('products', 'public');
            }
            $data['image_path'] = $path;
        }

        $product->update($data);

        return response()->json($product);
    }

    public function destroy($id)
    {
        $product = Product::findOrFail($id);
        if ($product->image_path) {
            Storage::disk('public')->delete($product->image_path);
        }
        $product->delete();

        return response()->json(['message' => __('messages.product_deleted')]);
    }
}
