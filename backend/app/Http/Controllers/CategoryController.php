<?php

namespace App\Http\Controllers;

use App\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class CategoryController extends Controller
{
    public function index()
    {
        return response()->json(Category::all());
    }

    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'icon' => 'nullable|image|mimes:jpeg,png,jpg,gif|max:1024',
        ]);

        $data = $request->only('name');

        if ($request->hasFile('icon')) {
            $file = $request->file('icon');
            $manager = new \Intervention\Image\ImageManager(new \Intervention\Image\Drivers\Gd\Driver());
            $image = $manager->read($file);
            $image->cover(200, 200);

            $path = 'categories/' . $file->hashName();
            Storage::disk('public')->put($path, (string) $image->toJpeg(80));
            $data['icon_url'] = asset('storage/' . $path);
        }

        $category = Category::create($data);

        return response()->json($category, 201);
    }

    public function update(Request $request, $id)
    {
        $category = Category::findOrFail($id);

        $request->validate([
            'name' => 'sometimes|string|max:255',
            'icon' => 'nullable|image|mimes:jpeg,png,jpg,gif|max:1024',
        ]);

        if ($request->has('name')) {
            $category->name = $request->name;
        }

        if ($request->hasFile('icon')) {
            // Delete old icon if it exists in local storage
            if ($category->icon_url && str_contains($category->icon_url, 'storage/categories')) {
                $oldPath = str_replace(asset('storage/'), '', $category->icon_url);
                Storage::disk('public')->delete($oldPath);
            }

            $file = $request->file('icon');
            $manager = new \Intervention\Image\ImageManager(new \Intervention\Image\Drivers\Gd\Driver());
            $image = $manager->read($file);
            $image->cover(200, 200);

            $path = 'categories/' . $file->hashName();
            Storage::disk('public')->put($path, (string) $image->toJpeg(80));
            $category->icon_url = asset('storage/' . $path);
        }

        $category->save();

        return response()->json($category);
    }

    public function destroy($id)
    {
        $category = Category::findOrFail($id);

        if ($category->icon_url && str_contains($category->icon_url, 'storage/categories')) {
            $oldPath = str_replace(asset('storage/'), '', $category->icon_url);
            Storage::disk('public')->delete($oldPath);
        }

        $category->delete();

        return response()->json(['message' => __('messages.category_deleted')]);
    }
}
