import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:frontend/models/product.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/l10n/app_localization.dart';

class AddProductScreen extends StatefulWidget {
  final Product? product; // If provided, we are in Edit mode
  const AddProductScreen({super.key, this.product});

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
  bool _isSaving = false;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _descController.text = widget.product!.description ?? '';
      _priceController.text = widget.product!.price.toString();
      _stockController.text = widget.product!.stock.toString();
      _selectedCategoryId = widget.product!.categoryId;
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _runAiAgent() async {
    if (_image == null && _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Provide a name or image for AI.')));
      return;
    }

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
          if (productProvider.categories.isNotEmpty) {
            final category = productProvider.categories.firstWhere(
              (c) => c.name.toLowerCase() == categoryName.toString().toLowerCase(),
              orElse: () => productProvider.categories.first,
            );
            _selectedCategoryId = category.id;
          }
        });
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI Error: $e')));
    } finally {
      if (mounted) setState(() => _isAiLoading = false);
    }
  }

  Future<void> _saveProduct() async {
    if (_selectedCategoryId == null || _nameController.text.isEmpty || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields.')));
      return;
    }

    setState(() => _isSaving = true);

    final isEdit = widget.product != null;
    final url = isEdit
        ? '${ApiService.baseUrl}/products/${widget.product!.id}'
        : '${ApiService.baseUrl}/products';

    final request = http.MultipartRequest('POST', Uri.parse(url)); // Laravel often needs POST with _method=PUT
    final token = await _apiService.getToken();
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    if (isEdit) request.fields['_method'] = 'PUT'; // For Laravel Update
    request.fields['name'] = _nameController.text;
    request.fields['description'] = _descController.text;
    request.fields['price'] = _priceController.text;
    request.fields['stock'] = _stockController.text.isEmpty ? '0' : _stockController.text;
    request.fields['category_id'] = _selectedCategoryId.toString();

    if (_image != null) {
      request.files.add(await http.MultipartFile.fromPath('image', _image!.path));
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (context.mounted) {
          Navigator.pop(context);
          Provider.of<ProductProvider>(context, listen: false).fetchProducts();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Success!')));
        }
      } else {
        if (context.mounted) {
          final err = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${err['message'] ?? 'Failed'}')));
        }
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final l10n = AppLocalization.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.product == null ? (l10n?.translate('add_product') ?? 'Add Product') : (l10n?.translate('edit_product') ?? 'Edit Product'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: _image != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_image!, fit: BoxFit.cover))
                    : (widget.product?.imagePath != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(widget.product!.fullImageUrl, fit: BoxFit.cover))
                        : const Icon(Icons.add_a_photo, size: 50, color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 20),
            if (widget.product == null)
              ElevatedButton.icon(
                onPressed: _isAiLoading ? null : _runAiAgent,
                icon: _isAiLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                label: Text(l10n?.translate('use_ai_details') ?? 'Use AI to Generate Details'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade50, foregroundColor: Colors.purple, minimumSize: const Size(double.infinity, 50)),
              ),
            const SizedBox(height: 20),
            TextField(controller: _nameController, decoration: InputDecoration(labelText: l10n?.translate('product_name') ?? 'Product Name')),
            const SizedBox(height: 10),
            TextField(controller: _descController, decoration: InputDecoration(labelText: l10n?.translate('description') ?? 'Description'), maxLines: 3),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: _priceController, decoration: InputDecoration(labelText: l10n?.translate('price_etb') ?? 'Price (ETB)'), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _stockController, decoration: InputDecoration(labelText: l10n?.translate('stock') ?? 'Stock'), keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              value: _selectedCategoryId,
              items: productProvider.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
              onChanged: (val) => setState(() => _selectedCategoryId = val),
              decoration: InputDecoration(labelText: l10n?.translate('category') ?? 'Category'),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveProduct,
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
              child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : Text(l10n?.translate('save') ?? 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
