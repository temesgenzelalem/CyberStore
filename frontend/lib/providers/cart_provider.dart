import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/models/product.dart';
import 'package:frontend/services/api_service.dart';

class CartItemModel {
  final int id;
  final Product product;
  int quantity;

  CartItemModel({required this.id, required this.product, required this.quantity});
}

class CartProvider with ChangeNotifier {
  final ApiService _apiService;
  List<CartItemModel> _items = [];
  bool _isLoading = false;

  CartProvider({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  List<CartItemModel> get items => _items;
  bool get isLoading => _isLoading;

  double get totalAmount => _items.fold(0, (sum, item) => sum + (item.product.price * item.quantity));

  Future<void> fetchCart() async {
    final token = await _apiService.getToken();
    if (token == null) return;

    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.get('/cart');
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        _items = data.map((item) => CartItemModel(
          id: item['id'],
          product: Product.fromJson(item['product']),
          quantity: item['quantity'],
        )).toList();
      }
    } catch (e) {
      debugPrint('Error fetching cart: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addToCart(Product product, {int quantity = 1}) async {
    final token = await _apiService.getToken();
    if (token == null) {
      // Local management for guest
      int index = _items.indexWhere((item) => item.product.id == product.id);
      if (index != -1) {
        _items[index].quantity += quantity;
      } else {
        _items.add(CartItemModel(
          id: DateTime.now().millisecondsSinceEpoch,
          product: product,
          quantity: quantity,
        ));
      }
      notifyListeners();
      return;
    }

    final response = await _apiService.post('/cart', {
      'product_id': product.id,
      'quantity': quantity,
    });
    if (response.statusCode == 200) {
      await fetchCart();
    }
  }

  Future<void> removeFromCart(int itemId) async {
    final token = await _apiService.getToken();
    if (token == null) {
      _items.removeWhere((item) => item.id == itemId);
      notifyListeners();
      return;
    }

    final response = await _apiService.delete('/cart/$itemId');
    if (response.statusCode == 200) {
      _items.removeWhere((item) => item.id == itemId);
      notifyListeners();
    }
  }

  Future<void> clearCart() async {
    final token = await _apiService.getToken();
    if (token == null) {
      _items.clear();
      notifyListeners();
      return;
    }

    final response = await _apiService.delete('/cart');
    if (response.statusCode == 200) {
      _items.clear();
      notifyListeners();
    }
  }

  /// Sync local guest cart items to backend after login
  Future<void> syncCart() async {
    final token = await _apiService.getToken();
    if (token != null && _items.isNotEmpty) {
      for (var item in _items) {
        await _apiService.post('/cart', {
          'product_id': item.product.id,
          'quantity': item.quantity,
        });
      }
      await fetchCart();
    }
  }
}
