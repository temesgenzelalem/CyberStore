import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/locale_provider.dart';
import 'package:frontend/providers/theme_provider.dart';
import 'package:frontend/l10n/app_localization.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalization.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.translate('settings') ?? 'Settings')),
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n?.translate('language') ?? 'Language'),
            subtitle: Text(localeProvider.locale.languageCode == 'en' ? 'English' : 'Amharic'),
            trailing: DropdownButton<String>(
              value: localeProvider.locale.languageCode,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  localeProvider.setLocale(Locale(newValue));
                }
              },
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'am', child: Text('Amharic')),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: themeProvider.isDarkMode,
            onChanged: (bool value) {
              themeProvider.toggleDarkMode();
            },
            secondary: const Icon(Icons.dark_mode),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              l10n?.translate('theme') ?? 'Theme',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Wrap(
            spacing: 10,
            alignment: WrapAlignment.center,
            children: ThemeProvider.themeOptions.keys.map((name) {
              final color = ThemeProvider.themeOptions[name]!;
              final isSelected = themeProvider.themeName == name;
              return GestureDetector(
                onTap: () => themeProvider.setTheme(name),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected ? Border.all(color: Colors.black, width: 3) : null,
                    boxShadow: [
                      if (isSelected) BoxShadow(color: color.withOpacity(0.5), blurRadius: 10)
                    ],
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              themeProvider.themeName,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeProvider.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}
