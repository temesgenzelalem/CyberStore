<?php

namespace App\Http\Controllers;

use App\Models\Product;
use App\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class AiController extends Controller
{
    public function customerAssistant(Request $request)
    {
        try {
            Log::info('Ping test starting...');
            $response = Http::get('https://www.google.com');
            return response()->json(['answer' => 'Server is online. Ping to Google: ' . $response->status()]);
        } catch (\Exception $e) {
            return response()->json(['answer' => 'Ping fail: ' . $e->getMessage()], 500);
        }
    }

    public function adminCommand(Request $request) { return response()->json(['message' => 'Admin active']); }
    public function adminAgent(Request $request) { return response()->json(['message' => 'Agent active']); }
}
