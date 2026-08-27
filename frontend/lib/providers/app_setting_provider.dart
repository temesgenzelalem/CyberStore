import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';

class AppSettingProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  Map<String, String> _settings = {
    'primary_color': 'blue',
    'is_dark_mode': 'false',
    'featured_banner_title': 'Welcome to CyberStore',
  };

  Map<String, String> get settings => _settings;

  AppSettingProvider() {
    fetchSettings();
  }

  Future<void> fetchSettings() async {
    final response = await _apiService.get('/app-settings');
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      _settings = data.map((key, value) => MapEntry(key, value.toString()));
      notifyListeners();
    }
  }

  Color get primaryColor {
    switch (_settings['primary_color']?.toLowerCase()) {
      case 'red': return Colors.red;
      case 'green': return Colors.green;
      case 'orange': return Colors.orange;
      case 'purple': return Colors.purple;
      case 'pink': return Colors.pink;
      default: return Colors.blue;
    }
  }

  bool get isDarkMode => _settings['is_dark_mode'] == 'true';
}
