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
        $key = env('GEMINI_API_KEY');
        if (!$key) {
            Log::error('GEMINI_API_KEY is missing in environment variables.');
        }
        return $key;
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
                return response()->json(['answer' => 'AI Configuration error: API Key missing.'], 500);
            }

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

            Log::error('Gemini API Error: ' . $response->body());
            return response()->json(['answer' => 'I am currently unable to reach my brain. Please try again later.'], 500);

        } catch (\Exception $e) {
            Log::error('AI Assistant Exception: ' . $e->getMessage());
            return response()->json(['answer' => 'An unexpected error occurred in the AI service.'], 500);
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
                Log::error('Admin Gemini API Error: ' . $response->body());
                return response()->json(['message' => 'AI Agent unreachable or failed.'], 500);
            }

            $candidate = $response->json('candidates.0');
            $part = $candidate['content']['parts'][0] ?? null;

            if (isset($part['function_call'])) {
                $toolName = $part['function_call']['name'];
                $args = $part['function_call']['args'];

                $agentController = new StoreAgentController();
                // Pass name and args directly to ensure compatibility
                $fakeRequest = new Request();
                $fakeRequest->merge(['name' => $toolName, 'args' => $args]);
                $result = $agentController->executeTool($fakeRequest);

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
                'message' => $part['text'] ?? 'I processed your request but no specific action was identified.',
            ]);

        } catch (\Exception $e) {
            Log::error('Admin AI Exception: ' . $e->getMessage());
            return response()->json(['message' => 'Admin AI error: ' . $e->getMessage()], 500);
        }
    }

    public function adminAgent(Request $request)
    {
        $request->validate([
            'image' => 'nullable|image',
            'prompt' => 'nullable|string',
        ]);

        try {
            $instruction = "Act as a product manager. Generate a JSON object for a new product based on the input. Fields: name, description, price, category_name. Suggest one of these categories: ";
            $categories = Category::pluck('name')->toArray();
            $instruction .= implode(", ", $categories) . ".";

            $parts = [['text' => $instruction]];

            if ($request->has('prompt')) {
                $parts[] = ['text' => "User description: " . $request->prompt];
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
                return response()->json(json_decode($response->json('candidates.0.content.parts.0.text')));
            }

            Log::error('Admin Agent Gemini Error: ' . $response->body());
            return response()->json(['message' => 'AI Agent failed to process the image/prompt.'], 500);

        } catch (\Exception $e) {
            Log::error('Admin Agent Exception: ' . $e->getMessage());
            return response()->json(['message' => 'Admin AI Agent error.'], 500);
        }
    }
}
