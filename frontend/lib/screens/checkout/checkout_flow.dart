import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/cart_provider.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/screens/order_success_screen.dart';
import 'package:frontend/l10n/app_localization.dart';

class CheckoutFlow extends StatefulWidget {
  const CheckoutFlow({super.key});

  @override
  State<CheckoutFlow> createState() => _CheckoutFlowState();
}

class _CheckoutFlowState extends State<CheckoutFlow> {
  int _currentStep = 0;
  final ApiService _apiService = ApiService();
  bool _isProcessing = false;

  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _startPayment();
    }
  }

  void _startPayment() async {
    setState(() => _isProcessing = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final l10n = AppLocalization.of(context);

    Map<String, dynamic> body = {
      'shipping_address': _addressController.text,
    };

    if (authProvider.isGuestMode) {
      body['guest_email'] = _emailController.text;
      body['guest_name'] = _nameController.text;
      body['items'] = cartProvider.items.map((i) => {
        'product_id': i.product.id,
        'quantity': i.quantity,
      }).toList();
    }

    final response = await _apiService.post('/payment/initialize', body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final checkoutUrl = data['data']['checkout_url'];

      if (await canLaunchUrl(Uri.parse(checkoutUrl))) {
        await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);

        if (mounted) {
          Provider.of<CartProvider>(context, listen: false).clearCart();
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OrderSuccessScreen()));
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n?.translate('payment_failed') ?? 'Payment failed to initialize.')));
      }
    }
    setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final l10n = AppLocalization.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.translate('checkout') ?? 'Checkout')),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _nextStep,
        onStepCancel: () => _currentStep > 0 ? setState(() => _currentStep--) : Navigator.pop(context),
        steps: [
          Step(
            title: Text(l10n?.translate('order_summary') ?? 'Order Summary'),
            content: Column(
              children: cartProvider.items.map((item) => ListTile(
                title: Text(item.product.name),
                trailing: Text('${item.product.price * item.quantity} ETB'),
              )).toList(),
            ),
            isActive: _currentStep >= 0,
          ),
          Step(
            title: Text(l10n?.translate('details') ?? 'Details'),
            content: Column(
              children: [
                if (authProvider.isGuestMode) ...[
                  TextField(controller: _emailController, decoration: InputDecoration(labelText: l10n?.translate('email') ?? 'Email')),
                  TextField(controller: _nameController, decoration: InputDecoration(labelText: l10n?.translate('full_name') ?? 'Full Name')),
                ],
                TextField(controller: _addressController, decoration: InputDecoration(labelText: l10n?.translate('shipping_address') ?? 'Shipping Address')),
                TextField(controller: _phoneController, decoration: InputDecoration(labelText: l10n?.translate('phone_number') ?? 'Phone Number')),
              ],
            ),
            isActive: _currentStep >= 1,
          ),
          Step(
            title: Text(l10n?.translate('payment') ?? 'Payment'),
            content: Column(
              children: [
                Text(l10n?.translate('chapa_redirect') ?? 'You will be redirected to Chapa to complete the payment.'),
                const SizedBox(height: 10),
                Text('${l10n?.translate('total') ?? 'Total'}: ${cartProvider.totalAmount} ETB', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            isActive: _currentStep >= 2,
          ),
        ],
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _isProcessing ? null : details.onStepContinue,
                  child: Text(_currentStep == 2 ? (l10n?.translate('pay_with_chapa') ?? 'Pay with Chapa') : (l10n?.translate('next') ?? 'Next')),
                ),
                TextButton(onPressed: details.onStepCancel, child: Text(l10n?.translate('back') ?? 'Back')),
              ],
            ),
          );
        },
      ),
    );
  }
}
