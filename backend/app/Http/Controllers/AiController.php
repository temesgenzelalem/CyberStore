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
                $context .= "There are currently no products in the store. Tell the user we are getting ready to launch soon!";
            }

            $context .= "\nRespond to the user helpfully in $languageName language. ";
            $context .= "Always provide your answer in a natural conversational tone.";

            $apiKey = $this->getGeminiApiKey();
            if (!$apiKey) {
                return response()->json(['answer' => 'Backend Error: GEMINI_API_KEY is missing in Render settings.'], 500);
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

            // Return the SPECIFIC error from Google so the user can see it
            $errorData = $response->json();
            $errorMsg = $errorData['error']['message'] ?? 'Unknown Gemini Error';

            return response()->json([
                'answer' => "Google AI Error: $errorMsg. Please ensure the 'Generative Language API' is enabled in Google Cloud for your project 328852332044."
            ], 500);

        } catch (\Exception $e) {
            Log::error('AI Assistant Exception: ' . $e->getMessage());
            return response()->json(['answer' => 'System error: ' . $e->getMessage()], 500);
        }
    }

    public function adminCommand(Request $request)
    {
        $request->validate(['prompt' => 'required|string']);

        try {
            $tools = StoreAgentController::getToolDefinitions();
            $apiKey = $this->getGeminiApiKey();

            if (!$apiKey) {
                return response()->json(['message' => 'Missing GEMINI_API_KEY'], 500);
            }

            $response = Http::timeout(30)->post("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey", [
                'contents' => [['parts' => [['text' => $request->prompt]]]],
                'tools' => [['function_declarations' => $tools]],
            ]);

            if (!$response->successful()) {
                $errorMsg = $response->json('error.message') ?? 'Unknown Error';
                return response()->json(['message' => "AI Agent failed: $errorMsg"], 500);
            }

            $candidate = $response->json('candidates.0');
            $part = $candidate['content']['parts'][0] ?? null;

            if (isset($part['function_call'])) {
                $toolName = $part['function_call']['name'];
                $args = $part['function_call']['args'];

                $agentController = new StoreAgentController();
                $fakeRequest = new Request();
                $fakeRequest->merge(['name' => $toolName, 'args' => (array)$args]);

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
                'message' => $part['text'] ?? 'I heard you, but I couldn\'t identify a specific command to run.',
            ]);

        } catch (\Exception $e) {
            return response()->json(['message' => 'System error: ' . $e->getMessage()], 500);
        }
    }

    public function adminAgent(Request $request)
    {
        $request->validate([
            'image' => 'nullable|image',
            'prompt' => 'nullable|string',
        ]);

        try {
            $categories = Category::pluck('name')->toArray();
            $instruction = "Act as a product manager. Generate a JSON object for a new product. Fields: name, description, price, category_name. Categories: " . implode(", ", $categories);

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

            $errorMsg = $response->json('error.message') ?? 'AI Analysis failed';
            return response()->json(['message' => "AI Error: $errorMsg"], 500);

        } catch (\Exception $e) {
            return response()->json(['message' => 'Analysis system error: ' . $e->getMessage()], 500);
        }
    }
}
