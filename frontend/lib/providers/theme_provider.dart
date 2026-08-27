import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/services/api_service.dart';
import 'dart:convert';

class ThemeProvider with ChangeNotifier {
  Color _primaryColor = Colors.blue;
  String _themeName = 'Cyber Blue';
  bool _isDarkMode = false;
  final ApiService _apiService = ApiService();

  Color get primaryColor => _primaryColor;
  String get themeName => _themeName;
  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
    refreshFromGlobal();
  }

  static const Map<String, Color> themeOptions = {
    'Cyber Blue': Colors.blue,
    'Neon Purple': Colors.purple,
    'Emerald Green': Colors.green,
    'Sunset Orange': Colors.orange,
    'Cyber Red': Colors.red,
  };

  Future<void> refreshFromGlobal() async {
    final response = await _apiService.get('/app-settings');
    if (response.statusCode == 200) {
      final Map<String, dynamic> settings = jsonDecode(response.body);

      if (settings.containsKey('primary_color')) {
        String colorName = settings['primary_color'];
        _primaryColor = _getColorFromName(colorName);
      }

      if (settings.containsKey('is_dark_mode')) {
        _isDarkMode = settings['is_dark_mode'] == 'true';
      }
      notifyListeners();
    }
  }

  Color _getColorFromName(String name) {
    switch (name.toLowerCase()) {
      case 'red': return Colors.red;
      case 'green': return Colors.green;
      case 'orange': return Colors.orange;
      case 'purple': return Colors.purple;
      case 'pink': return Colors.pink;
      default: return Colors.blue;
    }
  }

  void toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', _isDarkMode);
  }

  void setTheme(String name) async {
    if (themeOptions.containsKey(name)) {
      _themeName = name;
      _primaryColor = themeOptions[name]!;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_name', name);
    }
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    String? name = prefs.getString('theme_name');
    _isDarkMode = prefs.getBool('is_dark_mode') ?? false;

    if (name != null && themeOptions.containsKey(name)) {
      _themeName = name;
      _primaryColor = themeOptions[name]!;
    }
    notifyListeners();
  }

  ThemeData get themeData {
    return ThemeData(
      brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      ),
      useMaterial3: true,
      fontFamily: 'Roboto',
      appBarTheme: AppBarTheme(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}
