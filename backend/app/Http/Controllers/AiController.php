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
        return env('GEMINI_API_KEY');
    }

    public function customerAssistant(Request $request)
    {
        Log::info('AI Chat: Request received.');

        try {
            $request->validate(['message' => 'required|string']);
            Log::info('AI Chat: Validation passed.');

            $products = Product::with('category')->take(10)->get();
            $categories = Category::pluck('name')->toArray();
            $locale = App::getLocale();
            $languageName = $locale == 'am' ? 'Amharic' : 'English';

            $context = "You are an AI assistant for CyberStore, an e-commerce app in Ethiopia. ";
            $context .= "Available categories: " . implode(", ", $categories) . ". ";

            if ($products->isNotEmpty()) {
                $context .= "Current top products: ";
                foreach ($products as $p) {
                    $catName = $p->category->name ?? 'General';
                    $context .= "ID: {$p->id}, Name: {$p->name} ($catName) - {$p->price} ETB. ";
                }
            } else {
                $context .= "There are currently no products. Inform the user we are launching soon.";
            }

            $context .= "\nRespond to the user helpfully in $languageName language. ";
            $context .= "Always provide your answer in a natural conversational tone.";

            $apiKey = $this->getGeminiApiKey();
            if (!$apiKey) {
                Log::error('AI Chat: GEMINI_API_KEY is missing.');
                return response()->json(['answer' => 'AI Configuration error: API Key missing.'], 500);
            }

            Log::info('AI Chat: Sending request to Google Gemini.');

            $response = Http::timeout(30)->post("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=" . $apiKey, [
                'contents' => [
                    [
                        'parts' => [
                            ['text' => $context . "\nUser: " . $request->message]
                        ]
                    ]
                ]
            ]);

            if ($response->successful()) {
                Log::info('AI Chat: Gemini response successful.');
                return response()->json([
                    'answer' => $response->json('candidates.0.content.parts.0.text')
                ]);
            }

            $errorMsg = $response->json('error.message') ?? 'Unknown Gemini Error';
            Log::error("AI Chat: Gemini API Error - " . $errorMsg);

            return response()->json([
                'answer' => "AI Service Error: $errorMsg"
            ], 500);

        } catch (\Exception $e) {
            Log::error('AI Chat: Fatal Exception - ' . $e->getMessage());
            Log::error($e->getTraceAsString());
            return response()->json(['answer' => 'System error in AI module: ' . $e->getMessage()], 500);
        }
    }

    public function adminCommand(Request $request)
    {
        Log::info('Admin AI: Request received.');

        try {
            $request->validate(['prompt' => 'required|string']);

            $tools = StoreAgentController::getToolDefinitions();
            $apiKey = $this->getGeminiApiKey();

            if (!$apiKey) {
                return response()->json(['message' => 'Missing API Key'], 500);
            }

            $response = Http::timeout(30)->post("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey", [
                'contents' => [['parts' => [['text' => $request->prompt]]]],
                'tools' => [['function_declarations' => $tools]],
            ]);

            if (!$response->successful()) {
                $error = $response->json('error.message') ?? 'Unknown API error';
                Log::error('Admin AI API Error: ' . $error);
                return response()->json(['message' => "AI Service unreachable: $error"], 500);
            }

            $candidate = $response->json('candidates.0');
            $part = $candidate['content']['parts'][0] ?? null;

            if (isset($part['function_call'])) {
                $toolName = $part['function_call']['name'];
                $args = $part['function_call']['args'];

                Log::info("Admin AI: Identified tool $toolName");

                $agentController = new StoreAgentController();

                $fakeRequest = new Request();
                $fakeRequest->merge(['name' => $toolName, 'args' => (array)$args]);

                $result = $agentController->executeTool($fakeRequest);
                Log::info("Admin AI: Tool result: " . json_encode($result));

                $secondResponse = Http::post("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey", [
                    'contents' => [
                        ['role' => 'user', 'parts' => [['text' => $request->prompt]]],
                        ['role' => 'model', 'parts' => [['function_call' => $part['function_call']]]],
                        [
                            'role' => 'function',
                            'parts' => [
                                [
                                    'function_response' => [
                                        'name' => $toolName,
                                        'response' => $result
                                    ]
                                ]
                            ]
                        ]
                    ],
                    'tools' => [['function_declarations' => $tools]],
                ]);

                return response()->json([
                    'message' => $secondResponse->json('candidates.0.content.parts.0.text') ?? $result['message'] ?? 'Action completed.',
                    'action_taken' => $toolName,
                    'result' => $result
                ]);
            }

            return response()->json([
                'message' => $part['text'] ?? 'Command not understood.',
            ]);

        } catch (\Exception $e) {
            Log::error('Admin AI Exception: ' . $e->getMessage());
            return response()->json(['message' => 'Admin system error: ' . $e->getMessage()], 500);
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
            $instruction = "Act as a product manager. Generate a JSON object for a new product. Fields: name, description, price, category_name. Use one of: " . implode(", ", $categories);

            $parts = [['text' => $instruction]];
            if ($request->has('prompt')) $parts[] = ['text' => "Input: " . $request->prompt];
            if ($request->hasFile('image')) {
                $imageData = base64_encode(file_get_contents($request->file('image')->path()));
                $parts[] = ['inline_data' => ['mime_type' => $request->file('image')->getMimeType(), 'data' => $imageData]];
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
            return response()->json(['message' => 'Analysis system error: ' . $e->getMessage()], 500);
        }
    }
}
