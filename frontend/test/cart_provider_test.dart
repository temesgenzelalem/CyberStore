import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:frontend/providers/cart_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/models/product.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MockApiService extends Mock implements ApiService {}

void main() {
  late CartProvider cartProvider;
  late MockApiService mockApiService;

  setUp(() {
    mockApiService = MockApiService();
    cartProvider = CartProvider(apiService: mockApiService);
  });

  group('CartProvider Tests', () {
    final product1 = Product(id: 1, categoryId: 1, name: 'P1', price: 100.0, stock: 10);
    final product2 = Product(id: 2, categoryId: 1, name: 'P2', price: 50.0, stock: 5);

    test('Initial total amount is 0', () {
      expect(cartProvider.totalAmount, 0.0);
      expect(cartProvider.items, isEmpty);
    });

    test('fetchCart updates items and total amount', () async {
      final cartJson = [
        {
          'id': 101,
          'quantity': 2,
          'product': {
            'id': 1,
            'category_id': 1,
            'name': 'P1',
            'price': '100.00',
            'stock': 10,
          }
        },
        {
          'id': 102,
          'quantity': 3,
          'product': {
            'id': 2,
            'category_id': 1,
            'name': 'P2',
            'price': '50.00',
            'stock': 5,
          }
        }
      ];

      when(() => mockApiService.get('/cart')).thenAnswer(
        (_) async => http.Response(jsonEncode(cartJson), 200),
      );

      await cartProvider.fetchCart();

      expect(cartProvider.items.length, 2);
      // (100 * 2) + (50 * 3) = 200 + 150 = 350
      expect(cartProvider.totalAmount, 350.0);
    });

    test('totalAmount recalculates correctly', () {
      // Manual population to test logic
      cartProvider.items.add(CartItemModel(id: 1, product: product1, quantity: 2));
      cartProvider.items.add(CartItemModel(id: 2, product: product2, quantity: 3));

      expect(cartProvider.totalAmount, 350.0);
    });
  });
}
