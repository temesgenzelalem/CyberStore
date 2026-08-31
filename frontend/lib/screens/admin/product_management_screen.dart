import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/screens/admin/add_product_screen.dart';
import 'package:frontend/l10n/app_localization.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => Provider.of<ProductProvider>(context, listen: false).fetchProducts());
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final l10n = AppLocalization.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.translate('manage_products') ?? 'Manage Products')),
      body: productProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: productProvider.products.length,
              itemBuilder: (context, index) {
                final product = productProvider.products[index];
                return ListTile(
                  leading: product.imagePath != null
                    ? Image.network(product.fullImageUrl, width: 50, height: 50, fit: BoxFit.cover)
                    : const Icon(Icons.shopping_bag),
                  title: Text(product.name),
                  subtitle: Text('${product.price} ETB - Stock: ${product.stock}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddProductScreen(product: product))),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            // Perform delete through API
                            await Provider.of<ProductProvider>(context, listen: false).deleteProduct(product.id);
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}
