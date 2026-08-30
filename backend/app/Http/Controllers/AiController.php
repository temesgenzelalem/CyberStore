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
                return response()->json(['answer' => 'AI Key missing on server.'], 500);
            }

            $products = Product::with('category')->take(5)->get();
            $categories = Category::pluck('name')->toArray();
            $locale = App::getLocale();
            $lang = $locale == 'am' ? 'Amharic' : 'English';

            $context = "AI Assistant for CyberStore Ethiopia. Categories: " . implode(", ", $categories) . ". ";
            if ($products->isNotEmpty()) {
                $context .= "Products: ";
                foreach ($products as $p) {
                    $context .= "{$p->name} ({$p->price} ETB). ";
                }
            }
            $context .= "\nReply in $lang.";

            $response = Http::timeout(30)->post("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=" . $apiKey, [
                'contents' => [['parts' => [['text' => $context . "\nUser: " . $request->message]]]]
            ]);

            if ($response->successful()) {
                return response()->json(['answer' => $response->json('candidates.0.content.parts.0.text')]);
            }

            $error = $response->json('error.message') ?? 'API Error ' . $response->status();
            return response()->json(['answer' => "AI Service: $error"], 500);

        } catch (\Exception $e) {
            return response()->json(['answer' => "Logic Error: " . $e->getMessage()], 500);
        }
    }

    public function adminCommand(Request $request)
    {
        try {
            $request->validate(['prompt' => 'required|string']);
            $tools = StoreAgentController::getToolDefinitions();
            $apiKey = $this->getGeminiApiKey();

            $response = Http::timeout(30)->post("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey", [
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
                    return response()->json(['message' => $result['message'] ?? 'Action done', 'action_taken' => $toolName]);
                }
                return response()->json(['message' => $part['text'] ?? 'Heard you.']);
            }
            return response()->json(['message' => 'Admin AI fail'], 500);
        } catch (\Exception $e) {
            return response()->json(['message' => 'Admin system crash'], 500);
        }
    }

    public function adminAgent(Request $request)
    {
        try {
            $request->validate(['image' => 'nullable|image', 'prompt' => 'nullable|string']);
            $apiKey = $this->getGeminiApiKey();
            $response = Http::timeout(60)->post("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey", [
                'contents' => [['parts' => [['text' => 'Generate product JSON for: ' . ($request->prompt ?? 'new item')]]]],
                'generationConfig' => ['response_mime_type' => 'application/json']
            ]);
            if ($response->successful()) return response()->json(json_decode($response->json('candidates.0.content.parts.0.text'), true));
            return response()->json(['message' => 'Agent analysis fail'], 500);
        } catch (\Exception $e) {
            return response()->json(['message' => 'Agent fatal error'], 500);
        }
    }
}
