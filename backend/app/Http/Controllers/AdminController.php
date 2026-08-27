<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\Order;
use Illuminate\Http\Request;

class AdminController extends Controller
{
    public function listUsers()
    {
        return response()->json(User::all());
    }

    public function updateUserRole(Request $request, $id)
    {
        $user = User::findOrFail($id);
        $request->validate(['role' => 'required|in:admin,customer']);
        $user->role = $request->role;
        $user->save();
        return response()->json(['message' => __('messages.user_role_updated'), 'user' => $user]);
    }

    public function listOrders()
    {
        return response()->json(Order::with('user', 'items.product')->orderBy('created_at', 'desc')->get());
    }

    public function updateOrderStatus(Request $request, $id)
    {
        $order = Order::findOrFail($id);
        $request->validate(['status' => 'required|string']);
        $oldStatus = $order->status;
        $order->status = $request->status;
        if ($request->has('tracking_number')) {
            $order->tracking_number = $request->tracking_number;
        }
        $order->save();

        // Notify user if status changed to Shipped or Delivered
        if ($order->user && $order->user->fcm_token && in_array($order->status, ['shipped', 'delivered'])) {
            $notificationService = new \App\Services\NotificationService();
            $title = $order->status == 'shipped' ? 'Your Order is Shipped!' : 'Order Delivered!';
            $body = "Order #{$order->id} status has been updated to {$order->status}.";
            $notificationService->sendNotification($order->user->fcm_token, $title, $body, ['order_id' => (string)$order->id]);
        }

        return response()->json(['message' => __('messages.order_status_updated'), 'order' => $order]);
    }

    public function stats()
    {
        $last7Days = collect(range(0, 6))->map(function($i) {
            $date = now()->subDays($i)->format('Y-m-d');
            $sales = Order::where('status', 'paid')
                ->whereDate('created_at', $date)
                ->sum('total_amount');
            return [
                'date' => $date,
                'sales' => (float)$sales
            ];
        })->reverse()->values();

        return response()->json([
            'total_sales' => Order::where('status', 'paid')->sum('total_amount'),
            'total_orders' => Order::count(),
            'total_users' => User::count(),
            'pending_orders' => Order::where('status', 'pending')->count(),
            'daily_sales' => $last7Days
        ]);
    }

    public function inventoryAlerts()
    {
        $lowStockProducts = \App\Models\Product::where('stock', '<', 5)->get();
        return response()->json($lowStockProducts);
    }
}
