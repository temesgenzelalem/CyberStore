<?php

namespace App\Services;

use Google\Client;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class NotificationService
{
    private $serviceAccountPath;

    public function __construct()
    {
        $this->serviceAccountPath = storage_path('app/firebase_service_account.json');
    }

    private function getAccessToken()
    {
        if (!file_exists($this->serviceAccountPath)) {
            Log::error('FCM Service Account file not found at ' . $this->serviceAccountPath);
            return null;
        }

        $client = new Client();
        $client->setAuthConfig($this->serviceAccountPath);
        $client->addScope('https://www.googleapis.com/auth/firebase.messaging');
        $client->fetchAccessTokenWithAssertion();
        $token = $client->getAccessToken();

        return $token['access_token'] ?? null;
    }

    public function sendNotification($token, $title, $body, $data = [])
    {
        $accessToken = $this->getAccessToken();
        if (!$accessToken) return false;

        $projectConfig = json_decode(file_get_contents($this->serviceAccountPath), true);
        $projectId = $projectConfig['project_id'];

        $url = "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send";

        $message = [
            'message' => [
                'token' => $token,
                'notification' => [
                    'title' => $title,
                    'body' => $body,
                ],
                'data' => $data,
            ],
        ];

        $response = Http::withToken($accessToken)->post($url, $message);

        if ($response->successful()) {
            return true;
        }

        Log::error('FCM Send Error: ' . $response->body());
        return false;
    }

    public function sendToAll($title, $body, $data = [])
    {
        $tokens = \App\Models\User::whereNotNull('fcm_token')->pluck('fcm_token');
        $successCount = 0;

        foreach ($tokens as $token) {
            if ($this->sendNotification($token, $title, $body, $data)) {
                $successCount++;
            }
        }

        return $successCount;
    }
}
