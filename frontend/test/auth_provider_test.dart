import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/models/user.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late AuthProvider authProvider;
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
    authProvider = AuthProvider(authService: mockAuthService);
  });

  group('AuthProvider Tests', () {
    final testUser = User(id: 1, name: 'Test User', email: 'test@example.com', role: 'customer');

    test('Initial state is unauthenticated', () {
      expect(authProvider.user, isNull);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.isLoading, isFalse);
    });

    test('login success updates state', () async {
      when(() => mockAuthService.login(any(), any())).thenAnswer((_) async => testUser);

      final success = await authProvider.login('test@example.com', 'password');

      expect(success, isTrue);
      expect(authProvider.user, testUser);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.isLoading, isFalse);
      verify(() => mockAuthService.login('test@example.com', 'password')).called(1);
    });

    test('login failure keeps state unauthenticated', () async {
      when(() => mockAuthService.login(any(), any())).thenAnswer((_) async => null);

      final success = await authProvider.login('test@example.com', 'wrong');

      expect(success, isFalse);
      expect(authProvider.user, isNull);
      expect(authProvider.isAuthenticated, isFalse);
    });

    test('logout clears user state', () async {
      when(() => mockAuthService.login(any(), any())).thenAnswer((_) async => testUser);
      when(() => mockAuthService.logout()).thenAnswer((_) async => {});

      await authProvider.login('test@example.com', 'password');
      expect(authProvider.isAuthenticated, isTrue);

      await authProvider.logout();

      expect(authProvider.user, isNull);
      expect(authProvider.isAuthenticated, isFalse);
      verify(() => mockAuthService.logout()).called(1);
    });
  });
}
