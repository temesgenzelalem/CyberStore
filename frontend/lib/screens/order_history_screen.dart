import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/order_provider.dart';
import 'package:intl/intl.dart';
import 'package:frontend/l10n/app_localization.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => Provider.of<OrderProvider>(context, listen: false).fetchMyOrders());
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final l10n = AppLocalization.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.translate('order_history') ?? 'My Orders')),
      body: orderProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : orderProvider.myOrders.isEmpty
              ? const Center(child: Text('No orders found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orderProvider.myOrders.length,
                  itemBuilder: (context, index) {
                    final order = orderProvider.myOrders[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 15),
                      child: ExpansionTile(
                        title: Text('Order #${order.id} - ${order.totalAmount} ETB'),
                        subtitle: Text('Status: ${order.status.toUpperCase()} | ${DateFormat.yMMMd().format(order.createdAt)}'),
                        children: [
                          ...order.items.map((item) => ListTile(
                                leading: const Icon(Icons.shopping_bag),
                                title: Text(item.product?.name ?? 'Product'),
                                subtitle: Text('${item.price} ETB x ${item.quantity}'),
                              )),
                          if (order.trackingNumber != null)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text('Tracking Number: ${order.trackingNumber}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
