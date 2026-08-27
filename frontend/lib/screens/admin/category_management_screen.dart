import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/l10n/app_localization.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => Provider.of<ProductProvider>(context, listen: false).fetchCategories());
  }

  void _showAddEditDialog({Map<String, dynamic>? category}) {
    final l10n = AppLocalization.of(context);
    final nameController = TextEditingController(text: category?['name']);
    File? iconFile;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(category == null ? (l10n?.translate('add_category') ?? 'Add Category') : (l10n?.translate('edit_category') ?? 'Edit Category')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: InputDecoration(labelText: l10n?.translate('category_name') ?? 'Category Name')),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.gallery);
                  if (picked != null) {
                    setDialogState(() => iconFile = File(picked.path));
                  }
                },
                child: Container(
                  height: 80,
                  width: 80,
                  color: Colors.grey[200],
                  child: iconFile != null
                      ? Image.file(iconFile!, fit: BoxFit.cover)
                      : (category?['icon_url'] != null
                          ? Image.network(category!['icon_url'], fit: BoxFit.cover)
                          : const Icon(Icons.add_a_photo)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n?.translate('cancel') ?? 'Cancel')),
            ElevatedButton(
              onPressed: () async {
                final request = http.MultipartRequest(
                  'POST',
                  Uri.parse(category == null
                      ? '${ApiService.baseUrl}/categories'
                      : '${ApiService.baseUrl}/categories/${category['id']}'),
                );
                final token = await _apiService.getToken();
                request.headers['Authorization'] = 'Bearer $token';
                request.headers['Accept'] = 'application/json';
                request.fields['name'] = nameController.text;
                if (iconFile != null) {
                  request.files.add(await http.MultipartFile.fromPath('icon', iconFile!.path));
                }

                final response = await request.send();
                if (response.statusCode == 200 || response.statusCode == 201) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    Provider.of<ProductProvider>(context, listen: false).fetchCategories();
                  }
                }
              },
              child: Text(l10n?.translate('save') ?? 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final l10n = AppLocalization.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.translate('manage_categories') ?? 'Manage Categories')),
      body: ListView.builder(
        itemCount: productProvider.categories.length,
        itemBuilder: (context, index) {
          final cat = productProvider.categories[index];
          return ListTile(
            leading: cat.iconUrl != null
              ? Image.network(cat.iconUrl!, width: 40, height: 40, fit: BoxFit.cover)
              : const Icon(Icons.category),
            title: Text(cat.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit), onPressed: () => _showAddEditDialog(category: {'id': cat.id, 'name': cat.name, 'icon_url': cat.iconUrl})),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final response = await _apiService.delete('/categories/${cat.id}');
                    if (response.statusCode == 200) {
                      productProvider.fetchCategories();
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
