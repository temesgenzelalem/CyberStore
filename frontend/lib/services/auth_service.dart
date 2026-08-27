import 'dart:convert';
import 'package:frontend/models/user.dart';
import 'package:frontend/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final ApiService _apiService = ApiService();

  Future<User?> login(String email, String password) async {
    final response = await _apiService.post('/login', {
      'email': email,
      'password': password,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', data['access_token']);
      return User.fromJson(data['user']);
    }
    return null;
  }

  Future<User?> register(String name, String email, String password) async {
    final response = await _apiService.post('/register', {
      'name': name,
      'email': email,
      'password': password,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', data['access_token']);
      return User.fromJson(data['user']);
    }
    return null;
  }

  Future<void> logout() async {
    await _apiService.post('/logout', {});
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  Future<User?> getCurrentUser() async {
    final response = await _apiService.get('/user');
    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    }
    return null;
  }

  Future<bool> updateProfile({String? name, String? email, String? password}) async {
    final response = await _apiService.post('/profile/update', {
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (password != null) 'password': password,
    });
    return response.statusCode == 200;
  }
}
