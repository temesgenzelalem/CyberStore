<?php

namespace App\Http\Controllers;

use App\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Log;

class CategoryController extends Controller
{
    public function index()
    {
        return response()->json(Category::all());
    }

    public function store(Request $request)
    {
        try {
            $request->validate([
                'name' => 'required|string|max:255',
                'icon' => 'nullable|image|max:5120',
            ]);

            $data = $request->only('name');

            if ($request->hasFile('icon')) {
                // SAVING RAW - Bypassing GD extension for stability
                $path = $request->file('icon')->store('categories', 'public');
                $data['icon_url'] = asset('storage/' . $path);
            }

            $category = Category::create($data);
            return response()->json($category, 201);
        } catch (\Exception $e) {
            Log::error('Category Store Error: ' . $e->getMessage());
            return response()->json(['message' => 'Failed to save category.'], 500);
        }
    }

    public function update(Request $request, $id)
    {
        $category = Category::findOrFail($id);

        try {
            $request->validate([
                'name' => 'sometimes|string|max:255',
                'icon' => 'nullable|image|max:5120',
            ]);

            if ($request->has('name')) {
                $category->name = $request->name;
            }

            if ($request->hasFile('icon')) {
                // Delete old icon if it exists
                if ($category->icon_url && str_contains($category->icon_url, 'storage/categories')) {
                    $oldPath = str_replace(asset('storage/'), '', $category->icon_url);
                    Storage::disk('public')->delete($oldPath);
                }

                $path = $request->file('icon')->store('categories', 'public');
                $category->icon_url = asset('storage/' . $path);
            }

            $category->save();
            return response()->json($category);
        } catch (\Exception $e) {
            return response()->json(['message' => 'Update failed: ' . $e->getMessage()], 500);
        }
    }

    public function destroy($id)
    {
        $category = Category::findOrFail($id);
        if ($category->icon_url && str_contains($category->icon_url, 'storage/categories')) {
            $oldPath = str_replace(asset('storage/'), '', $category->icon_url);
            Storage::disk('public')->delete($oldPath);
        }
        $category->delete();
        return response()->json(['message' => 'Deleted']);
    }
}
