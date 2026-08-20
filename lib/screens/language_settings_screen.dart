// lib/screens/language_settings_screen.dart
//
// Brief section 4.3 "Localization and Language Support": Romanian and
// English ship at launch; Spanish, French and German are architected for
// but not yet enabled.
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  String _selected = 'en';

  void _select(String code) {
    setState(() => _selected = code);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Language preference saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(title: const Text('Language')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.outerPadding),
        children: [
          const SectionHeader('Available at launch'),
          Card(
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'en',
                  groupValue: _selected,
                  title: const Text('English'),
                  onChanged: (v) => _select(v!),
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  value: 'ro',
                  groupValue: _selected,
                  title: const Text('Română'),
                  onChanged: (v) => _select(v!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader('Coming soon'),
          Card(
            child: Column(
              children: [
                for (final lang in const [('Español', 'es'), ('Français', 'fr'), ('Deutsch', 'de')])
                  ListTile(
                    title: Text(lang.$1, style: TextStyle(color: onSurface.withOpacity(0.4))),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: onSurface.withOpacity(0.2)),
                      ),
                      child: Text(
                        'Soon',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: onSurface.withOpacity(0.5)),
                      ),
                    ),
                    enabled: false,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
