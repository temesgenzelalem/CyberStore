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
        try {
            $request->validate(['message' => 'required|string']);

            $apiKey = $this->getGeminiApiKey();
            if (!$apiKey) {
                return response()->json(['answer' => 'AI Configuration error: Key not found on server.'], 500);
            }

            // Simplest possible context
            $context = "You are an assistant for CyberStore Ethiopia. Reply helpfully.";

            $response = Http::timeout(15)->post("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=" . $apiKey, [
                'contents' => [
                    ['parts' => [['text' => $context . "\nUser: " . $request->message]]]
                ]
            ]);

            if ($response->successful()) {
                $text = $response->json('candidates.0.content.parts.0.text') ?? 'Success, but no text returned.';
                return response()->json(['answer' => $text]);
            }

            // If not successful, return the EXACT error from Google
            $googleError = $response->json('error.message') ?? 'Unknown Google API Error';
            return response()->json(['answer' => "Google Error: $googleError"], 500);

        } catch (\Exception $e) {
            // This will tell us the EXACT line that failed
            return response()->json([
                'answer' => "Backend Fatal: " . $e->getMessage() . " in " . $e->getFile() . " on line " . $e->getLine()
            ], 500);
        }
    }

    public function adminCommand(Request $request)
    {
        try {
            $request->validate(['prompt' => 'required|string']);
            $tools = StoreAgentController::getToolDefinitions();
            $apiKey = $this->getGeminiApiKey();

            $response = Http::timeout(15)->post("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey", [
                'contents' => [['parts' => [['text' => $request->prompt]]]],
                'tools' => [['function_declarations' => $tools]],
            ]);

            if ($response->successful()) {
                $part = $response->json('candidates.0.content.parts.0');
                if (isset($part['function_call'])) {
                    $toolName = $part['function_call']['name'];
                    $args = (array)($part['function_call']['args'] ?? []);
                    $agent = new StoreAgentController();
                    $fakeReq = new Request();
                    $fakeReq->merge(['name' => $toolName, 'args' => $args]);
                    $result = $agent->executeTool($fakeReq);
                    return response()->json(['message' => $result['message'] ?? 'Done', 'action_taken' => $toolName]);
                }
                return response()->json(['message' => $part['text'] ?? 'Heard you.']);
            }
            return response()->json(['message' => 'Admin AI error: ' . $response->json('error.message')], 500);
        } catch (\Exception $e) {
            return response()->json(['message' => 'Admin system crash: ' . $e->getMessage()], 500);
        }
    }

    public function adminAgent(Request $request)
    {
        try {
            $request->validate(['image' => 'nullable|image', 'prompt' => 'nullable|string']);
            $apiKey = $this->getGeminiApiKey();
            $response = Http::timeout(30)->post("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey", [
                'contents' => [['parts' => [['text' => 'Generate product JSON for: ' . ($request->prompt ?? 'new product')]]]],
                'generationConfig' => ['response_mime_type' => 'application/json']
            ]);
            if ($response->successful()) return response()->json(json_decode($response->json('candidates.0.content.parts.0.text'), true));
            return response()->json(['message' => 'Agent analysis fail'], 500);
        } catch (\Exception $e) {
            return response()->json(['message' => 'Agent fatal: ' . $e->getMessage()], 500);
        }
    }
}
