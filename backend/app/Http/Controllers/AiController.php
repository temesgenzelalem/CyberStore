<?php

namespace App\Http\Controllers;

use App\Models\Product;
use App\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\Log;
use App\Http\Controllers\StoreAgentController;

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
                return response()->json(['answer' => 'AI setup missing on server.'], 500);
            }

            // Database Context
            $products = Product::with('category')->take(10)->get();
            $categories = Category::pluck('name')->toArray();
            $locale = App::getLocale();
            $language = $locale == 'am' ? 'Amharic' : 'English';

            $context = "You are a helpful assistant for CyberStore Ethiopia. ";
            $context .= "Categories: " . implode(", ", $categories) . ". ";

            if ($products->isNotEmpty()) {
                $context .= "Products: ";
                foreach ($products as $p) {
                    $context .= "{$p->name} - {$p->price} ETB. ";
                }
            }

            $context .= "\nReply in $language language.";

            // Attempt call to Google
            $response = Http::timeout(30)->post("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=" . $apiKey, [
                'contents' => [['parts' => [['text' => $context . "\nUser: " . $request->message]]]]
            ]);

            if ($response->successful()) {
                $answer = $response->json('candidates.0.content.parts.0.text') ?? 'I am listening, but I have no answer.';
                return response()->json(['answer' => $answer]);
            }

            $error = $response->json('error.message') ?? 'Google API error ' . $response->status();
            return response()->json(['answer' => "AI Error: $error"], 500);

        } catch (\Exception $e) {
            Log::error("AI Fatal: " . $e->getMessage());
            return response()->json(['answer' => "System Error: " . $e->getMessage()], 500);
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

            if (!$response->successful()) {
                return response()->json(['message' => 'AI Command failed: ' . ($response->json('error.message') ?? 'API Error')], 500);
            }

            $part = $response->json('candidates.0.content.parts.0');

            if (isset($part['function_call'])) {
                $toolName = $part['function_call']['name'];
                $args = (array)($part['function_call']['args'] ?? []);

                $agent = new StoreAgentController();
                $fakeReq = new Request();
                $fakeReq->merge(['name' => $toolName, 'args' => $args]);
                $result = $agent->executeTool($fakeReq);

                return response()->json([
                    'message' => $result['message'] ?? 'Command executed.',
                    'action_taken' => $toolName,
                ]);
            }

            return response()->json(['message' => $part['text'] ?? 'No command recognized.']);

        } catch (\Exception $e) {
            return response()->json(['message' => 'Admin AI system error.'], 500);
        }
    }

    public function adminAgent(Request $request)
    {
        try {
            $request->validate([
                'image' => 'nullable|image',
                'prompt' => 'nullable|string',
            ]);

            $categories = Category::pluck('name')->toArray();
            $instruction = "Generate product JSON (name, description, price, category_name) from input. Categories: " . implode(", ", $categories);

            $parts = [['text' => $instruction]];
            if ($request->has('prompt')) $parts[] = ['text' => "User: " . $request->prompt];
            if ($request->hasFile('image')) {
                $parts[] = [
                    'inline_data' => [
                        'mime_type' => $request->file('image')->getMimeType(),
                        'data' => base64_encode(file_get_contents($request->file('image')->path()))
                    ]
                ];
            }

            $apiKey = $this->getGeminiApiKey();
            $response = Http::timeout(60)->post("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=" . $apiKey, [
                'contents' => [['parts' => $parts]],
                'generationConfig' => ['response_mime_type' => 'application/json']
            ]);

            if ($response->successful()) {
                return response()->json(json_decode($response->json('candidates.0.content.parts.0.text'), true));
            }

            return response()->json(['message' => 'AI Analysis failed.'], 500);

        } catch (\Exception $e) {
            return response()->json(['message' => 'System error in analysis.'], 500);
        }
    }
}
