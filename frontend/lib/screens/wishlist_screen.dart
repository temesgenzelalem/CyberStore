import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/wishlist_provider.dart';
import 'package:frontend/screens/product_details_screen.dart';
import 'package:frontend/l10n/app_localization.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => Provider.of<WishlistProvider>(context, listen: false).fetchWishlist());
  }

  @override
  Widget build(BuildContext context) {
    final wishlistProvider = Provider.of<WishlistProvider>(context);
    final l10n = AppLocalization.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.translate('my_wishlist') ?? 'My Wishlist')),
      body: wishlistProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : wishlistProvider.items.isEmpty
              ? Center(child: Text(l10n?.translate('wishlist_empty') ?? 'Your wishlist is empty'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                  ),
                  itemCount: wishlistProvider.items.length,
                  itemBuilder: (context, index) {
                    final product = wishlistProvider.items[index];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: product)),
                      ),
                      child: Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Image.network(product.fullImageUrl, width: double.infinity, fit: BoxFit.cover)),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
