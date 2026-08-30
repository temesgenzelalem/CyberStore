<?php

namespace App\Http\Controllers;

use App\Models\Product;
use App\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\Log;

class AiController extends Controller
{
    private function getGeminiApiKey()
    {
        return trim(env('GEMINI_API_KEY'));
    }

    public function customerAssistant(Request $request)
    {
        // Absolute minimum logic to prevent crash
        $msg = $request->input('message', 'Hello');
        $key = $this->getGeminiApiKey();

        if (!$key) {
            return response()->json(['answer' => 'AI Configuration missing.'], 500);
        }

        try {
            $response = Http::timeout(10)->post("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$key", [
                'contents' => [['parts' => [['text' => $msg]]]]
            ]);

            if ($response->successful()) {
                $text = $response->json('candidates.0.content.parts.0.text') ?? 'No words.';
                return response()->json(['answer' => $text]);
            }

            return response()->json(['answer' => 'Google Error: ' . $response->status()], 500);
        } catch (\Exception $e) {
            return response()->json(['answer' => 'Crash: ' . $e->getMessage()], 500);
        }
    }

    public function adminCommand(Request $request) { return response()->json(['message' => 'Admin tools active']); }
    public function adminAgent(Request $request) { return response()->json(['message' => 'Agent active']); }
}
