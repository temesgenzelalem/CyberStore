import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/widgets/admin_sales_chart.dart';
import 'package:frontend/screens/admin/product_management_screen.dart';
import 'package:frontend/screens/admin/order_management_screen.dart';
import 'package:frontend/screens/admin/user_management_screen.dart';
import 'package:frontend/screens/admin/category_management_screen.dart';
import 'package:frontend/screens/admin/ai_command_screen.dart';
import 'package:frontend/l10n/app_localization.dart';
import 'package:provider/provider.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final response = await _apiService.get('/admin/stats');
    if (response.statusCode == 200) {
      if (mounted) {
        setState(() {
          _stats = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n?.translate('admin_dashboard') ?? 'Admin Dashboard')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n?.translate('sales_overview') ?? 'Sales Overview (Last 7 Days)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  AdminSalesChart(dailySales: _stats?['daily_sales'] ?? []),
                  const SizedBox(height: 20),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildStatCard(context, l10n?.translate('manage_products') ?? 'Manage Products', Icons.inventory, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductManagementScreen()));
                      }),
                      _buildStatCard(context, l10n?.translate('manage_users') ?? 'Manage Users', Icons.people, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen()));
                      }),
                      _buildStatCard(context, l10n?.translate('view_orders') ?? 'View Orders', Icons.shopping_bag, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderManagementScreen()));
                      }),
                      _buildStatCard(context, l10n?.translate('ai_manager') ?? 'AI Manager', Icons.auto_awesome, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AiCommandScreen()));
                      }),
                      _buildStatCard(context, l10n?.translate('categories') ?? 'Categories', Icons.category, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryManagementScreen()));
                      }),
                      _buildStatCard(context, l10n?.translate('inventory_alerts') ?? 'Inventory Alerts', Icons.warning, () => _showLowStock(context),
                        badge: _stats?['pending_orders'].toString()),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  void _showLowStock(BuildContext context) async {
    final l10n = AppLocalization.of(context);
    final response = await _apiService.get('/admin/inventory-alerts');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n?.translate('low_stock_alert') ?? 'Low Stock Alert'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: data.length,
                itemBuilder: (context, index) => ListTile(
                  title: Text(data[index]['name']),
                  trailing: Text('${l10n?.translate('stock')}: ${data[index]['stock']}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n?.translate('close') ?? 'Close'))],
          ),
        );
      }
    }
  }

  Widget _buildStatCard(BuildContext context, String title, IconData icon, VoidCallback onTap, {String? badge}) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 4,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 50, color: Theme.of(context).primaryColor),
                  const SizedBox(height: 10),
                  Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            if (badge != null && badge != '0')
              Positioned(
                right: 10,
                top: 10,
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.red,
                  child: Text(badge, style: const TextStyle(fontSize: 10, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
