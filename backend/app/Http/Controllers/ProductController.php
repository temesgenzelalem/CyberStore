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
        $query = Product::with('category')->orderBy('is_featured', 'desc')->orderBy('created_at', 'desc');
        if ($request->has('category_id')) $query->where('category_id', $request->category_id);
        if ($request->has('search')) $query->where('name', 'like', '%' . $request->search . '%');
        return response()->json($query->get());
    }

    public function categories()
    {
        return response()->json(Category::all());
    }

    public function show($id)
    {
        return response()->json(Product::with('category')->findOrFail($id));
    }

    public function store(Request $request)
    {
        try {
            $request->validate([
                'category_id' => 'required|exists:categories,id',
                'name' => 'required|string|max:255',
                'description' => 'nullable|string',
                'price' => 'required|numeric',
                'stock' => 'required|integer',
                'image' => 'nullable|image|max:10240', // 10MB max
            ]);

            $data = $request->except('image');

            if ($request->hasFile('image')) {
                // NO COMPRESSION - Saving raw to save RAM on Render Free tier
                $path = $request->file('image')->store('products', 'public');
                $data['image_path'] = $path;
            }

            $product = Product::create($data);
            return response()->json($product, 201);

        } catch (\Exception $e) {
            Log::error('Store Product Error: ' . $e->getMessage());
            return response()->json(['message' => 'Server Error: ' . $e->getMessage()], 500);
        }
    }

    public function update(Request $request, $id)
    {
        $product = Product::findOrFail($id);
        $data = $request->all();
        if ($request->hasFile('image')) {
            $path = $request->file('image')->store('products', 'public');
            $data['image_path'] = $path;
        }
        $product->update($data);
        return response()->json($product);
    }

    public function destroy($id)
    {
        Product::destroy($id);
        return response()->json(['message' => 'Deleted']);
    }
}
