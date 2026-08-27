import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/l10n/app_localization.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  int? _selectedCategoryId;
  File? _image;
  bool _isAiLoading = false;

  final ApiService _apiService = ApiService();

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _runAiAgent() async {
    setState(() => _isAiLoading = true);

    final request = http.MultipartRequest('POST', Uri.parse('${ApiService.baseUrl}/ai/agent'));
    final token = await _apiService.getToken();
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    if (_image != null) {
      request.files.add(await http.MultipartFile.fromPath('image', _image!.path));
    }

    if (_nameController.text.isNotEmpty) {
      request.fields['prompt'] = _nameController.text;
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _nameController.text = data['name'] ?? _nameController.text;
          _descController.text = data['description'] ?? _descController.text;
          _priceController.text = (data['price'] ?? 0).toString();

          final categoryName = data['category_name'];
          final productProvider = Provider.of<ProductProvider>(context, listen: false);
          final category = productProvider.categories.firstWhere(
            (c) => c.name.toLowerCase() == categoryName.toString().toLowerCase(),
            orElse: () => productProvider.categories.first,
          );
          _selectedCategoryId = category.id;
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI Agent error: $e')));
      }
    } finally {
      setState(() => _isAiLoading = false);
    }
  }

  Future<void> _saveProduct() async {
    final request = http.MultipartRequest('POST', Uri.parse('${ApiService.baseUrl}/products'));
    final token = await _apiService.getToken();
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    request.fields['name'] = _nameController.text;
    request.fields['description'] = _descController.text;
    request.fields['price'] = _priceController.text;
    request.fields['stock'] = _stockController.text;
    request.fields['category_id'] = _selectedCategoryId.toString();

    if (_image != null) {
      request.files.add(await http.MultipartFile.fromPath('image', _image!.path));
    }

    final streamedResponse = await request.send();
    if (streamedResponse.statusCode == 201) {
      if (context.mounted) {
        Navigator.pop(context);
        Provider.of<ProductProvider>(context, listen: false).fetchProducts();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final l10n = AppLocalization.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.translate('add_product') ?? 'Add Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                color: Colors.grey[200],
                child: _image != null
                    ? Image.file(_image!, fit: BoxFit.cover)
                    : const Icon(Icons.add_a_photo, size: 50),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _runAiAgent,
              icon: _isAiLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
              label: const Text('Use AI to Generate Details'),
            ),
            const SizedBox(height: 20),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Product Name')),
            TextField(controller: _descController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
            TextField(controller: _priceController, decoration: const InputDecoration(labelText: 'Price (ETB)'), keyboardType: TextInputType.number),
            TextField(controller: _stockController, decoration: const InputDecoration(labelText: 'Stock'), keyboardType: TextInputType.number),
            DropdownButtonFormField<int>(
              value: _selectedCategoryId,
              items: productProvider.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
              onChanged: (val) => setState(() => _selectedCategoryId = val),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _saveProduct,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text('Save Product'),
            ),
          ],
        ),
      ),
    );
  }
}
