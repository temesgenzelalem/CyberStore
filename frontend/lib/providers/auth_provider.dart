import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/config.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  final ApiService _apiService = ApiService();
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  User? _user;
  bool _isLoading = false;
  bool _isGuestMode = false;
  bool _isGoogleInitialized = false;

  AuthProvider({AuthService? authService}) : _authService = authService ?? AuthService();

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get isGuestMode => _isGuestMode;

  void enableGuestMode() {
    _isGuestMode = true;
    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      if (!_isGoogleInitialized) {
        await _googleSignIn.initialize(
          serverClientId: AppConfig.googleClientId,
        );
        _isGoogleInitialized = true;
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final response = await _apiService.post('/login/google', {
        'id_token': googleAuth.idToken,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access_token']);
        _user = User.fromJson(data['user']);
        _isGuestMode = false;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    _user = await _authService.login(email, password);
    if (_user != null) _isGuestMode = false;
    _isLoading = false;
    notifyListeners();
    return _user != null;
  }

  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    notifyListeners();
    _user = await _authService.register(name, email, password);
    if (_user != null) _isGuestMode = false;
    _isLoading = false;
    notifyListeners();
    return _user != null;
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _isGuestMode = false;
    notifyListeners();
  }

  Future<void> checkAuth() async {
    _user = await _authService.getCurrentUser();
    notifyListeners();
  }

  Future<bool> uploadAvatar(File image) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('${ApiService.baseUrl}/profile/avatar'));
      final token = await _apiService.getToken();
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.files.add(await http.MultipartFile.fromPath('avatar', image.path));

      final streamedResponse = await request.send();
      if (streamedResponse.statusCode == 200) {
        await checkAuth();
        return true;
      }
    } catch (e) {
      debugPrint('Avatar Upload Error: $e');
    }
    return false;
  }

  Future<bool> updateAdminSettings({String? email, String? password}) async {
    final success = await _authService.updateProfile(email: email, password: password);
    if (success) {
      await checkAuth();
    }
    return success;
  }
}
