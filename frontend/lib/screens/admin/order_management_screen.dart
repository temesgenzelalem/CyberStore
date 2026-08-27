import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/order_provider.dart';
import 'package:frontend/l10n/app_localization.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => Provider.of<OrderProvider>(context, listen: false).fetchAdminOrders());
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final l10n = AppLocalization.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.translate('manage_orders') ?? 'Manage Orders')),
      body: orderProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orderProvider.adminOrders.length,
              itemBuilder: (context, index) {
                final order = orderProvider.adminOrders[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 15),
                  child: ExpansionTile(
                    title: Text('Order #${order.id} - ${order.user?.name ?? l10n?.translate('guest_user') ?? 'Guest User'}'),
                    subtitle: Text('${l10n?.translate('total')}: ${order.totalAmount} ETB'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${l10n?.translate('update_status') ?? 'Update Status'}:'),
                            DropdownButton<String>(
                              value: order.status,
                              onChanged: (val) {
                                if (val != null) {
                                  orderProvider.updateOrderStatus(order.id, val);
                                }
                              },
                              items: [
                                DropdownMenuItem(value: 'pending', child: Text(l10n?.translate('status_pending') ?? 'Pending')),
                                DropdownMenuItem(value: 'paid', child: Text(l10n?.translate('status_paid') ?? 'Paid')),
                                DropdownMenuItem(value: 'shipped', child: Text(l10n?.translate('status_shipped') ?? 'Shipped')),
                                DropdownMenuItem(value: 'delivered', child: Text(l10n?.translate('status_delivered') ?? 'Delivered')),
                                DropdownMenuItem(value: 'cancelled', child: Text(l10n?.translate('status_cancelled') ?? 'Cancelled')),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ...order.items.map((item) => ListTile(
                            title: Text(item.product?.name ?? 'Product'),
                            subtitle: Text('${item.price} ETB x ${item.quantity}'),
                          )),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
