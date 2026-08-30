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

            $products = Product::with('category')->take(5)->get();
            $categories = Category::pluck('name')->toArray();
            $lang = App::getLocale() == 'am' ? 'Amharic' : 'English';

            $context = "CyberStore Ethiopia Assistant. Categories: " . implode(", ", $categories) . ". ";
            if ($products->isNotEmpty()) {
                $context .= "Products: ";
                foreach ($products as $p) { $context .= "{$p->name} ({$p->price} ETB). "; }
            }
            $context .= "Reply in $lang.";

            // Using the ultra-stable versioned model name for absolute compatibility
            $response = Http::timeout(30)->post("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=" . $apiKey, [
                'contents' => [['parts' => [['text' => $context . "\nUser: " . $request->message]]]]
            ]);

            if ($response->successful()) {
                return response()->json(['answer' => $response->json('candidates.0.content.parts.0.text')]);
            }

            return response()->json(['answer' => "AI Service Error: " . ($response->json('error.message') ?? 'Unknown')], 500);

        } catch (\Exception $e) {
            return response()->json(['answer' => "Fatal error in AI module."], 500);
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
                    return response()->json(['message' => $result['message'] ?? 'Done', 'action_taken' => $toolName]);
                }
                return response()->json(['message' => $part['text'] ?? 'Heard you.']);
            }
            return response()->json(['message' => 'Admin AI failure.'], 500);
        } catch (\Exception $e) {
            return response()->json(['message' => 'Admin AI system error.'], 500);
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
            return response()->json(['message' => 'Agent analysis failure.'], 500);
        } catch (\Exception $e) {
            return response()->json(['message' => 'Agent fatal error.'], 500);
        }
    }
}
