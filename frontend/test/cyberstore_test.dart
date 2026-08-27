import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/main.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/providers/cart_provider.dart';
import 'package:frontend/providers/wishlist_provider.dart';

void main() {
  testWidgets('CyberStore Login Screen Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ProductProvider()),
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(create: (_) => WishlistProvider()),
        ],
        child: const MyApp(),
      ),
    );

    // Verify that we are on the login screen
    expect(find.text('CyberStore'), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
    expect(find.byType(TextField), findsNWidgets(2)); // Email and Password
    expect(find.text('Don\'t have an account? Register'), findsOneWidget);
  });
}
