import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/models/order.dart';
import 'package:frontend/services/api_service.dart';

class OrderProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Order> _myOrders = [];
  List<Order> _adminOrders = [];
  bool _isLoading = false;

  List<Order> get myOrders => _myOrders;
  List<Order> get adminOrders => _adminOrders;
  bool get isLoading => _isLoading;

  Future<void> fetchMyOrders() async {
    _isLoading = true;
    notifyListeners();
    final response = await _apiService.get('/orders');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      _myOrders = data.map((o) => Order.fromJson(o)).toList();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchAdminOrders() async {
    _isLoading = true;
    notifyListeners();
    final response = await _apiService.get('/admin/orders');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      _adminOrders = data.map((o) => Order.fromJson(o)).toList();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateOrderStatus(int orderId, String status, {String? trackingNumber}) async {
    final response = await _apiService.post('/admin/orders/$orderId/status', {
      'status': status,
      if (trackingNumber != null) 'tracking_number': trackingNumber,
    });
    if (response.statusCode == 200) {
      await fetchAdminOrders();
      return true;
    }
    return false;
  }
}
