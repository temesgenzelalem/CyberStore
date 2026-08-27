class AppConfig {
  // Local Development:
  // static const String serverUrl = 'http://10.12.173.203:8000';

  // Production (Render):
  static const String serverUrl = 'https://YOUR-APP-NAME.onrender.com';

  static const String apiUrl = '$serverUrl/api';
  static const String storageUrl = '$serverUrl/storage';

  // Google Sign-In Client ID
  static const String googleClientId = '328852332044-eounsm2dgb8sdqutgqs0hcav1rrah9lu.apps.googleusercontent.com';
}
