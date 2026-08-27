<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\ProductController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

// Public Routes
Route::post('/login', [AuthController::class, 'login']);
Route::post('/login/google', [AuthController::class, 'loginWithGoogle']);
Route::post('/register', [AuthController::class, 'register']);
Route::post('/password/email', [\App\Http\Controllers\PasswordResetController::class, 'sendResetLinkEmail']);
Route::post('/password/reset', [\App\Http\Controllers\PasswordResetController::class, 'reset']);

Route::get('/products', [ProductController::class, 'index']);
Route::get('/products/{id}', [ProductController::class, 'show']);
Route::get('/products/{id}/reviews', [\App\Http\Controllers\ReviewController::class, 'index']);
Route::get('/categories', [\App\Http\Controllers\CategoryController::class, 'index']);
Route::get('/app-settings', [\App\Http\Controllers\StoreAgentController::class, 'getSettings']);

// Guest Payment
Route::post('/payment/initialize', [\App\Http\Controllers\PaymentController::class, 'initialize']);
Route::get('/payment/verify/{tx_ref}', [\App\Http\Controllers\PaymentController::class, 'callback'])->name('payment.callback');

// Protected Routes
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', function (Request $request) {
        return $request->user();
    });
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::post('/profile/update', [AuthController::class, 'updateProfile']);
    Route::post('/profile/avatar', [AuthController::class, 'uploadAvatar']);
    Route::post('/profile/fcm-token', [AuthController::class, 'updateFcmToken']);

    // Review Routes
    Route::post('/products/{id}/reviews', [\App\Http\Controllers\ReviewController::class, 'store']);

    // Cart Routes
    Route::get('/cart', [\App\Http\Controllers\CartController::class, 'index']);
    Route::post('/cart', [\App\Http\Controllers\CartController::class, 'store']);
    Route::delete('/cart/{id}', [\App\Http\Controllers\CartController::class, 'destroy']);
    Route::delete('/cart', [\App\Http\Controllers\CartController::class, 'clear']);

    // Wishlist Routes
    Route::get('/wishlist', [\App\Http\Controllers\WishlistController::class, 'index']);
    Route::post('/wishlist', [\App\Http\Controllers\WishlistController::class, 'store']);
    Route::delete('/wishlist/{id}', [\App\Http\Controllers\WishlistController::class, 'destroy']);

    // Payment Routes (for authenticated users)
    Route::get('/orders', [\App\Http\Controllers\PaymentController::class, 'myOrders']);

    // AI Assistant
    Route::post('/ai/chat', [\App\Http\Controllers\AiController::class, 'customerAssistant']);

    // Admin Routes
    Route::middleware('admin')->group(function () {
        Route::post('/ai/agent', [\App\Http\Controllers\AiController::class, 'adminAgent']);
        Route::post('/ai/admin-command', [\App\Http\Controllers\AiController::class, 'adminCommand']);
        Route::post('/products', [ProductController::class, 'store']);
        Route::post('/products/{id}', [ProductController::class, 'update']);
        Route::delete('/products/{id}', [ProductController::class, 'destroy']);

        // Category Management
        Route::post('/categories', [\App\Http\Controllers\CategoryController::class, 'store']);
        Route::post('/categories/{id}', [\App\Http\Controllers\CategoryController::class, 'update']);
        Route::delete('/categories/{id}', [\App\Http\Controllers\CategoryController::class, 'destroy']);

        // Admin Management
        Route::get('/admin/users', [\App\Http\Controllers\AdminController::class, 'listUsers']);
        Route::post('/admin/users/{id}/role', [\App\Http\Controllers\AdminController::class, 'updateUserRole']);
        Route::get('/admin/orders', [\App\Http\Controllers\AdminController::class, 'listOrders']);
        Route::post('/admin/orders/{id}/status', [\App\Http\Controllers\AdminController::class, 'updateOrderStatus']);
        Route::get('/admin/stats', [\App\Http\Controllers\AdminController::class, 'stats']);
        Route::get('/admin/inventory-alerts', [\App\Http\Controllers\AdminController::class, 'inventoryAlerts']);
    });
});
