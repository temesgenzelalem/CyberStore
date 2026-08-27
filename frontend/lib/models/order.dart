import 'package:frontend/models/product.dart';
import 'package:frontend/models/user.dart';

class OrderItem {
  final int id;
  final int productId;
  final int quantity;
  final double price;
  final Product? product;

  OrderItem({required this.id, required this.productId, required this.quantity, required this.price, this.product});

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'],
      productId: json['product_id'],
      quantity: json['quantity'],
      price: double.parse(json['price'].toString()),
      product: json['product'] != null ? Product.fromJson(json['product']) : null,
    );
  }
}

class Order {
  final int id;
  final int userId;
  final double totalAmount;
  final String status;
  final String? txRef;
  final String? trackingNumber;
  final DateTime createdAt;
  final List<OrderItem> items;
  final User? user;

  Order({
    required this.id,
    required this.userId,
    required this.totalAmount,
    required this.status,
    this.txRef,
    this.trackingNumber,
    required this.createdAt,
    required this.items,
    this.user,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      userId: json['user_id'],
      totalAmount: double.parse(json['total_amount'].toString()),
      status: json['status'],
      txRef: json['tx_ref'],
      trackingNumber: json['tracking_number'],
      createdAt: DateTime.parse(json['created_at']),
      items: (json['items'] as List).map((i) => OrderItem.fromJson(i)).toList(),
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }
}
