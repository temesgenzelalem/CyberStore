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
        $request->validate(['message' => 'required|string']);

        try {
            $products = Product::with('category')->take(20)->get();
            $categories = Category::pluck('name')->toArray();
            $locale = App::getLocale();
            $languageName = $locale == 'am' ? 'Amharic' : 'English';

            $context = "You are an AI assistant for CyberStore, an e-commerce app in Ethiopia. ";
            $context .= "Available categories: " . implode(", ", $categories) . ". ";
            $context .= "Current top products: ";
            foreach ($products as $p) {
                $context .= "ID: {$p->id}, Name: {$p->name} (" . ($p->category->name ?? 'N/A') . ") - {$p->price} ETB. ";
            }
            $context .= "\nRespond to the user helpfully in $languageName language. ";
            $context .= "If you think the user is looking for a specific type of product, you can mention it. ";
            $context .= "Always provide your answer in a natural conversational tone.";

            $apiKey = $this->getGeminiApiKey();
            if (!$apiKey) {
                return response()->json(['answer' => 'Backend Error: GEMINI_API_KEY is missing in Render settings.'], 500);
            }

            // Enhanced debugging: Log the URL (without key) and context
            Log::info('AI Chat Request sent to Gemini.');

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
                return response()->json([
                    'answer' => $response->json('candidates.0.content.parts.0.text')
                ]);
            }

            $errorMsg = $response->json('error.message') ?? 'Unknown Gemini Error';
            $errorCode = $response->json('error.status') ?? 'NO_STATUS';

            Log::error("Gemini API Error ($errorCode): " . $errorMsg);

            return response()->json([
                'answer' => "AI Brain Error: $errorMsg ($errorCode). Please check your API key on Render."
            ], 500);

        } catch (\Exception $e) {
            Log::error('AI Assistant Exception: ' . $e->getMessage());
            return response()->json(['answer' => 'System Exception: ' . $e->getMessage()], 500);
        }
    }

    public function adminCommand(Request $request)
    {
        $request->validate(['prompt' => 'required|string']);

        try {
            $tools = StoreAgentController::getToolDefinitions();
            $apiKey = $this->getGeminiApiKey();

            if (!$apiKey) {
                return response()->json(['message' => 'Admin AI configuration error: API Key missing.'], 500);
            }

            $response = Http::timeout(30)->post("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey", [
                'contents' => [['parts' => [['text' => $request->prompt]]]],
                'tools' => [['function_declarations' => $tools]],
            ]);

            if (!$response->successful()) {
                $errorMsg = $response->json('error.message') ?? 'API Error';
                return response()->json(['message' => "AI Agent unreachable: $errorMsg"], 500);
            }

            $candidate = $response->json('candidates.0');
            $part = $candidate['content']['parts'][0] ?? null;

            if (isset($part['function_call'])) {
                $toolName = $part['function_call']['name'];
                $args = $part['function_call']['args'];

                $agentController = new StoreAgentController();

                $fakeRequest = new Request();
                $fakeRequest->merge(['name' => $toolName, 'args' => $args]);

                try {
                    $result = $agentController->executeTool($fakeRequest);
                } catch (\Exception $toolEx) {
                    return response()->json(['message' => "Command logic failed: " . $toolEx->getMessage()], 500);
                }

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
                    'message' => $secondResponse->json('candidates.0.content.parts.0.text') ?? $result['message'],
                    'action_taken' => $toolName,
                    'result' => $result
                ]);
            }

            return response()->json([
                'message' => $part['text'] ?? 'I heard you, but I couldn\'t find a command to run.',
            ]);

        } catch (\Exception $e) {
            return response()->json(['message' => 'Admin System Error: ' . $e->getMessage()], 500);
        }
    }

    public function adminAgent(Request $request)
    {
        $request->validate([
            'image' => 'nullable|image',
            'prompt' => 'nullable|string',
        ]);

        try {
            $instruction = "Act as a professional product manager. Generate a valid JSON object for a NEW product. Return ONLY the JSON. Fields: name, description, price, category_name. Available categories: ";
            $categories = Category::pluck('name')->toArray();
            $instruction .= implode(", ", $categories) . ".";

            $parts = [['text' => $instruction]];

            if ($request->has('prompt')) {
                $parts[] = ['text' => "Product Details: " . $request->prompt];
            }

            if ($request->hasFile('image')) {
                $imageData = base64_encode(file_get_contents($request->file('image')->path()));
                $parts[] = [
                    'inline_data' => [
                        'mime_type' => $request->file('image')->getMimeType(),
                        'data' => $imageData
                    ]
                ];
            }

            $apiKey = $this->getGeminiApiKey();
            $response = Http::timeout(60)->post("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=" . $apiKey, [
                'contents' => [['parts' => $parts]],
                'generationConfig' => [
                    'response_mime_type' => 'application/json',
                ]
            ]);

            if ($response->successful()) {
                $text = $response->json('candidates.0.content.parts.0.text');
                return response()->json(json_decode($text, true));
            }

            $errorMsg = $response->json('error.message') ?? 'AI Analysis Failed';
            return response()->json(['message' => "AI Error: $errorMsg"], 500);

        } catch (\Exception $e) {
            return response()->json(['message' => 'Agent Error: ' . $e->getMessage()], 500);
        }
    }
}
