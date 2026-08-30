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
                $context .= "We are currently setting up our inventory. Tell the user to check back soon for amazing deals!";
            }

            $context .= "\nRespond to the user helpfully in $languageName language. ";
            $context .= "Always provide your answer in a natural conversational tone.";

            $apiKey = $this->getGeminiApiKey();
            if (!$apiKey) {
                return response()->json(['answer' => 'AI not configured (Missing Key).'], 500);
            }

            $response = Http::timeout(30)
                ->withHeaders(['Content-Type' => 'application/json'])
                ->post("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=" . $apiKey, [
                    'contents' => [
                        [
                            'parts' => [
                                ['text' => $context . "\nUser: " . $request->message]
                            ]
                        ]
                    ]
                ]);

            if ($response->successful()) {
                $data = $response->json();
                $text = $data['candidates'][0]['content']['parts'][0]['text'] ?? 'I processed your request but have no words to say.';
                return response()->json(['answer' => $text]);
            }

            $errorMsg = 'API Connection Error';
            if ($response->json()) {
                $errorMsg = $response->json('error.message') ?? 'Unknown Gemini Error';
            }

            Log::error("Gemini API Error: " . $errorMsg);
            return response()->json(['answer' => "AI Error: $errorMsg"], 500);

        } catch (\Exception $e) {
            Log::error('AI Assistant Fatal: ' . $e->getMessage());
            return response()->json(['answer' => 'System error: ' . $e->getMessage()], 500);
        }
    }

    public function adminCommand(Request $request)
    {
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
                $error = 'API Failure';
                if ($response->json()) $error = $response->json('error.message') ?? 'Unknown';
                return response()->json(['message' => "AI Service Error: $error"], 500);
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

                $finalText = 'Action completed successfully.';
                if ($secondResponse->successful()) {
                    $finalText = $secondResponse->json('candidates.0.content.parts.0.text') ?? $finalText;
                }

                return response()->json([
                    'message' => $finalText,
                    'action_taken' => $toolName,
                    'result' => $result
                ]);
            }

            return response()->json([
                'message' => $part['text'] ?? 'I heard you, but no command was identified.',
            ]);

        } catch (\Exception $e) {
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
            $instruction = "Act as a product manager. Generate a JSON object for a new product. Return ONLY the JSON. Fields: name, description, price, category_name. Available categories: " . implode(", ", $categories);

            $parts = [['text' => $instruction]];
            if ($request->has('prompt')) $parts[] = ['text' => "Product Context: " . $request->prompt];
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
                $jsonText = $response->json('candidates.0.content.parts.0.text');
                return response()->json(json_decode($jsonText, true));
            }

            $error = 'AI Analysis failed';
            if ($response->json()) $error = $response->json('error.message') ?? $error;
            return response()->json(['message' => $error], 500);

        } catch (\Exception $e) {
            return response()->json(['message' => 'System error: ' . $e->getMessage()], 500);
        }
    }
}
