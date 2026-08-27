import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/register_screen.dart';
import 'package:frontend/screens/forgot_password_screen.dart';
import 'package:frontend/l10n/app_localization.dart';
import 'package:frontend/providers/theme_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _login() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final l10n = AppLocalization.of(context);
    final success = await authProvider.login(
      _emailController.text,
      _passwordController.text,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.translate('login_failed_creds') ?? 'Login failed. Please check your credentials.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n?.translate('app_title') ?? 'CyberStore',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: themeProvider.primaryColor),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: l10n?.translate('email') ?? 'Email', border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: l10n?.translate('password') ?? 'Password', border: const OutlineInputBorder()),
              obscureText: true,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                child: Text(l10n?.translate('forgot_password') ?? 'Forgot Password?'),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _login,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
              child: Text(l10n?.translate('login') ?? 'Login'),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () async {
                final success = await Provider.of<AuthProvider>(context, listen: false).signInWithGoogle();
                if (!success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n?.translate('google_signin_failed') ?? 'Google Sign-In failed')));
                }
              },
              icon: const Icon(Icons.login),
              label: Text(l10n?.translate('sign_in_google') ?? 'Sign in with Google'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                Provider.of<AuthProvider>(context, listen: false).enableGuestMode();
              },
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
              child: Text(l10n?.translate('continue_as_guest') ?? 'Continue as Guest'),
            ),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
              child: Text(l10n?.translate('dont_have_account') ?? 'Don\'t have an account? Register'),
            ),
          ],
        ),
      ),
    );
  }
}
