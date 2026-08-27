import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';

class NotificationProvider with ChangeNotifier {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final ApiService _apiService = ApiService();
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  NotificationProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    // Request permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');

      // Get the token
      _fcmToken = await _fcm.getToken();
      debugPrint("FCM Token: $_fcmToken");

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Message received: ${message.notification?.title}');
        // You could show a local notification or snackbar here
      });

      // Handle background message tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('Message opened from background: ${message.data}');
      });

      notifyListeners();
    } else {
      debugPrint('User declined or has not accepted permission');
    }
  }

  Future<void> syncTokenWithBackend() async {
    if (_fcmToken != null) {
      await _apiService.post('/profile/fcm-token', {'fcm_token': _fcmToken});
      debugPrint('FCM Token synced with backend');
    }
  }
}
