import 'package:frontend/models/category.dart';
import 'package:frontend/config.dart';

class Product {
  final int id;
  final int categoryId;
  final String name;
  final String? description;
  final double price;
  final int stock;
  final String? imagePath;
  final double rating;
  final int reviewCount;
  final Category? category;

  Product({
    required this.id,
    required this.categoryId,
    required this.name,
    this.description,
    required this.price,
    required this.stock,
    this.imagePath,
    this.rating = 0,
    this.reviewCount = 0,
    this.category,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      categoryId: json['category_id'],
      name: json['name'],
      description: json['description'],
      price: double.parse(json['price'].toString()),
      stock: json['stock'],
      imagePath: json['image_path'],
      rating: double.parse((json['rating'] ?? 0).toString()),
      reviewCount: json['review_count'] ?? 0,
      category: json['category'] != null ? Category.fromJson(json['category']) : null,
    );
  }

  String get fullImageUrl => imagePath != null ? '${AppConfig.storageUrl}/$imagePath' : 'https://via.placeholder.com/150';
}
