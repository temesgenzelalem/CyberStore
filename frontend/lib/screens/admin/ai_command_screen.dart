import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/app_setting_provider.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/providers/theme_provider.dart';
import 'package:frontend/l10n/app_localization.dart';

class AiCommandScreen extends StatefulWidget {
  const AiCommandScreen({super.key});

  @override
  State<AiCommandScreen> createState() => _AiCommandScreenState();
}

class _AiCommandScreenState extends State<AiCommandScreen> {
  final _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  void _sendCommand() async {
    if (_controller.text.isEmpty) return;

    final prompt = _controller.text;
    final l10n = AppLocalization.of(context);
    setState(() {
      _messages.add({'role': 'user', 'text': prompt});
      _isLoading = true;
    });
    _controller.clear();

    try {
      final response = await _apiService.post('/ai/admin-command', {'prompt': prompt});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messages.add({'role': 'ai', 'text': data['message']});
        });

        // Refresh local state based on action
        if (data.containsKey('action_taken')) {
          _refreshApp();
        }
      } else {
        setState(() {
          _messages.add({'role': 'ai', 'text': l10n?.translate('failed_execute_command') ?? 'Failed to execute command.'});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'ai', 'text': '${l10n?.translate('connection_error') ?? 'Connection error'}: $e'});
      });
    }

    setState(() => _isLoading = false);
  }

  void _refreshApp() {
    Provider.of<AppSettingProvider>(context, listen: false).fetchSettings();
    Provider.of<ProductProvider>(context, listen: false).fetchProducts();
    Provider.of<ThemeProvider>(context, listen: false).refreshFromGlobal();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n?.translate('ai_store_manager') ?? 'AI Store Manager')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(msg['text']!, style: const TextStyle(fontSize: 16)),
                  ),
                );
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: l10n?.translate('ai_command_hint') ?? 'e.g. Change color to red...',
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendCommand(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _sendCommand,
                  icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
