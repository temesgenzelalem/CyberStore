<?php

namespace App\Http\Controllers;

use App\Models\Review;
use App\Models\Product;
use Illuminate\Http\Request;

class ReviewController extends Controller
{
    public function index($productId)
    {
        $reviews = Review::with('user')->where('product_id', $productId)->get();
        return response()->json($reviews);
    }

    public function store(Request $request, $productId)
    {
        $request->validate([
            'rating' => 'required|integer|min:1|max:5',
            'comment' => 'nullable|string',
        ]);

        $review = Review::create([
            'user_id' => $request->user()->id,
            'product_id' => $productId,
            'rating' => $request->rating,
            'comment' => $request->comment,
        ]);

        // Update product rating
        $product = Product::findOrFail($productId);
        $avgRating = Review::where('product_id', $productId)->avg('rating');
        $count = Review::where('product_id', $productId)->count();

        $product->rating = $avgRating;
        $product->review_count = $count;
        $product->save();

        return response()->json($review->load('user'), 201);
    }
}
