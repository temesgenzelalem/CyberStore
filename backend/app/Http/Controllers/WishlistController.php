<?php

namespace App\Http\Controllers;

use App\Models\WishlistItem;
use App\Models\Product;
use Illuminate\Http\Request;

class WishlistController extends Controller
{
    public function index(Request $request)
    {
        $wishlist = WishlistItem::with('product')
            ->where('user_id', $request->user()->id)
            ->get();
        return response()->json($wishlist);
    }

    public function store(Request $request)
    {
        $request->validate([
            'product_id' => 'required|exists:products,id',
        ]);

        $wishlistItem = WishlistItem::firstOrCreate([
            'user_id' => $request->user()->id,
            'product_id' => $request->product_id,
        ]);

        return response()->json($wishlistItem->load('product'));
    }

    public function destroy(Request $request, $id)
    {
        $wishlistItem = WishlistItem::where('user_id', $request->user()->id)
            ->findOrFail($id);
        $wishlistItem->delete();

        return response()->json(['message' => __('messages.item_removed_wishlist')]);
    }
}
