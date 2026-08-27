<?php

namespace App\Http\Controllers;

use App\Models\Order;
use App\Models\OrderItem;
use App\Models\CartItem;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

class PaymentController extends Controller
{
    public function initialize(Request $request)
    {
        $user = $request->user();
        $isGuest = $user === null;

        if ($isGuest) {
            $request->validate([
                'guest_email' => 'required|email',
                'guest_name' => 'required|string',
                'items' => 'required|array',
                'items.*.product_id' => 'required|exists:products,id',
                'items.*.quantity' => 'required|integer|min:1',
            ]);

            $itemsData = $request->items;
            $total = 0;
            foreach ($itemsData as &$item) {
                $product = \App\Models\Product::find($item['product_id']);
                $item['price'] = $product->price;
                $total += $product->price * $item['quantity'];
            }
        } else {
            $cartItems = CartItem::with('product')->where('user_id', $user->id)->get();
            if ($cartItems->isEmpty()) {
                return response()->json(['message' => __('messages.cart_empty')], 400);
            }
            $total = $cartItems->sum(function ($item) {
                return $item->product->price * $item->quantity;
            });
        }

        $tx_ref = 'tx-' . Str::random(10);

        // Create Order
        $order = Order::create([
            'user_id' => $isGuest ? null : $user->id,
            'total_amount' => $total,
            'status' => 'pending',
            'tx_ref' => $tx_ref,
            'is_guest' => $isGuest,
            'guest_email' => $isGuest ? $request->guest_email : null,
            'guest_name' => $isGuest ? $request->guest_name : null,
            'shipping_address' => $request->shipping_address,
        ]);

        if ($isGuest) {
            foreach ($itemsData as $item) {
                OrderItem::create([
                    'order_id' => $order->id,
                    'product_id' => $item['product_id'],
                    'quantity' => $item['quantity'],
                    'price' => $item['price'],
                ]);
            }
        } else {
            foreach ($cartItems as $item) {
                OrderItem::create([
                    'order_id' => $order->id,
                    'product_id' => $item->product_id,
                    'quantity' => $item->quantity,
                    'price' => $item->product->price,
                ]);
            }
        }

        // Initialize Chapa Payment
        $chapaData = [
            'amount' => $total,
            'currency' => 'ETB',
            'email' => $isGuest ? $request->guest_email : $user->email,
            'first_name' => $isGuest ? $request->guest_name : $user->name,
            'last_name' => 'Customer',
            'tx_ref' => $tx_ref,
            'callback_url' => route('payment.callback', ['tx_ref' => $tx_ref]),
            'return_url' => 'https://cyberstore.app/payment-success',
            'customization' => [
                'title' => 'CyberStore Order',
                'description' => 'Payment for order #' . $order->id,
            ],
        ];

        $response = Http::withToken(env('CHAPA_SECRET_KEY'))
            ->post('https://api.chapa.co/v1/transaction/initialize', $chapaData);

        if ($response->successful()) {
            return response()->json($response->json());
        }

        return response()->json([
            'message' => __('messages.payment_failed'),
            'error' => $response->json(),
        ], 500);
    }

    public function callback(Request $request, $tx_ref)
    {
        $response = Http::withToken(env('CHAPA_SECRET_KEY'))
            ->get("https://api.chapa.co/v1/transaction/verify/{$tx_ref}");

        if ($response->successful() && $response->json('status') == 'success') {
            $order = Order::where('tx_ref', $tx_ref)->first();
            if ($order) {
                $order->status = 'paid';
                $order->save();

                // Clear cart after successful payment for authenticated users
                if ($order->user_id) {
                    CartItem::where('user_id', $order->user_id)->delete();
                }
            }
            return response()->json(['message' => __('messages.payment_verified')]);
        }

        return response()->json(['message' => __('messages.payment_failed')], 400);
    }

    public function myOrders(Request $request)
    {
        $orders = Order::with('items.product')
            ->where('user_id', $request->user()->id)
            ->orderBy('created_at', 'desc')
            ->get();
        return response()->json($orders);
    }
}
