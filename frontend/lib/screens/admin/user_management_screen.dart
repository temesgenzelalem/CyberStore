import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/l10n/app_localization.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final ApiService _apiService = ApiService();
  List<User> _users = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final response = await _apiService.get('/admin/users');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      if (mounted) {
        setState(() {
          _users = data.map((u) => User.fromJson(u)).toList();
        });
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _updateRole(int userId, String role) async {
    final response = await _apiService.post('/admin/users/$userId/role', {'role': role});
    if (response.statusCode == 200) {
      _fetchUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n?.translate('manage_users') ?? 'Manage Users')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(user.name),
                  subtitle: Text(user.email),
                  trailing: DropdownButton<String>(
                    value: user.role,
                    onChanged: (val) {
                      if (val != null) _updateRole(user.id, val);
                    },
                    items: const [
                      DropdownMenuItem(value: 'customer', child: Text('Customer')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
