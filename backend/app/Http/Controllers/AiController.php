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
        Log::info('AI CHAT START');

        try {
            $request->validate(['message' => 'required|string']);

            $apiKey = $this->getGeminiApiKey();
            if (!$apiKey) {
                return response()->json(['answer' => 'Backend Error: API Key missing.'], 500);
            }

            // Simplest possible request to test connection
            Log::info('AI CHAT: Sending to Google...');

            $response = Http::timeout(10)->post("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=" . $apiKey, [
                'contents' => [
                    ['parts' => [['text' => $request->message]]]
                ]
            ]);

            Log::info('AI CHAT: Google Responded. Status: ' . $response->status());

            if ($response->successful()) {
                $text = $response->json('candidates.0.content.parts.0.text') ?? 'I am here, but I have no answer.';
                return response()->json(['answer' => $text]);
            }

            $error = $response->json('error.message') ?? 'Unknown Error';
            return response()->json(['answer' => "Google API Error: $error"], 500);

        } catch (\Exception $e) {
            Log::error('AI CHAT FATAL: ' . $e->getMessage());
            return response()->json(['answer' => 'System error: ' . $e->getMessage()], 500);
        }
    }

    // Keep other methods as they are for now
    public function adminCommand(Request $request) { return response()->json(['message' => 'Admin command disabled during debug'], 500); }
    public function adminAgent(Request $request) { return response()->json(['message' => 'Admin agent disabled during debug'], 500); }
}
