import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/models/product.dart';
import 'package:frontend/providers/cart_provider.dart';
import 'package:frontend/providers/wishlist_provider.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/widgets/review_dialog.dart';
import 'package:frontend/l10n/app_localization.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;
  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  void _checkAuthAndExecute(VoidCallback action) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final l10n = AppLocalization.of(context);
    if (authProvider.isAuthenticated) {
      action();
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n?.translate('login_required') ?? 'Login Required'),
          content: Text(l10n?.translate('login_prompt') ?? 'Please login or register to add items to your cart or wishlist.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n?.translate('cancel') ?? 'Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              child: Text(l10n?.translate('login') ?? 'Login'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
        actions: [
          Consumer<WishlistProvider>(
            builder: (context, wishlist, child) {
              final isFav = wishlist.items.any((item) => item.id == widget.product.id);
              return IconButton(
                icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: Colors.red),
                onPressed: () => _checkAuthAndExecute(() => wishlist.toggleWishlist(widget.product)),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                image: DecorationImage(
                  image: NetworkImage(widget.product.fullImageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.product.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      Text(' ${widget.product.rating} (${widget.product.reviewCount} reviews)'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('${widget.product.price} ETB', style: const TextStyle(fontSize: 20, color: Colors.blue, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Text(l10n?.translate('description') ?? 'Description', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(widget.product.description ?? 'No description available.', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Text('${l10n?.translate('stock') ?? 'Stock'}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(widget.product.stock.toString()),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n?.translate('customer_reviews') ?? 'Customer Reviews', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () => _checkAuthAndExecute(() => showDialog(
                          context: context,
                          builder: (_) => ReviewDialog(productId: widget.product.id),
                        )),
                        child: Text(l10n?.translate('write_review') ?? 'Write a Review'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () {
            _checkAuthAndExecute(() {
              Provider.of<CartProvider>(context, listen: false).addToCart(widget.product);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n?.translate('added_to_cart') ?? 'Added to cart')),
              );
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
          child: Text(l10n?.translate('add_to_cart') ?? 'Add to Cart', style: const TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}
