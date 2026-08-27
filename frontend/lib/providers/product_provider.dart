import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/models/product.dart';
import 'package:frontend/models/category.dart';
import 'package:frontend/services/api_service.dart';

class ProductProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Product> _products = [];
  List<Category> _categories = [];
  bool _isLoading = false;

  List<Product> get products => _products;
  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;

  Future<void> fetchCategories() async {
    final response = await _apiService.get('/categories');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      _categories = data.map((item) => Category.fromJson(item)).toList();
      notifyListeners();
    }
  }

  Future<void> fetchProducts({int? categoryId, String? search}) async {
    if (_isLoading) return; // Prevent duplicate requests
    _isLoading = true;
    notifyListeners();

    String url = '/products?';
    if (categoryId != null) url += 'category_id=$categoryId&';
    if (search != null) url += 'search=$search';

    final response = await _apiService.get(url);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      _products = data.map((item) => Product.fromJson(item)).toList();
    }
    _isLoading = false;
    notifyListeners();
  }
}
