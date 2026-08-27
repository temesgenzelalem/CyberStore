import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/models/product.dart';
import 'package:frontend/services/api_service.dart';

class WishlistProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Product> _items = [];
  bool _isLoading = false;

  List<Product> get items => _items;
  bool get isLoading => _isLoading;

  Future<void> fetchWishlist() async {
    _isLoading = true;
    notifyListeners();
    final response = await _apiService.get('/wishlist');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      _items = data.map((item) => Product.fromJson(item['product'])).toList();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggleWishlist(Product product) async {
    final isExist = _items.any((item) => item.id == product.id);
    if (isExist) {
      // Find the wishlist item id to delete
      final response = await _apiService.get('/wishlist');
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final item = data.firstWhere((i) => i['product_id'] == product.id);
        await _apiService.delete('/wishlist/${item['id']}');
      }
    } else {
      await _apiService.post('/wishlist', {'product_id': product.id});
    }
    await fetchWishlist();
  }
}
