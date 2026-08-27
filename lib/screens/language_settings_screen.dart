// lib/screens/language_settings_screen.dart
//
// Brief section 4.3 "Localization and Language Support": Romanian and
// English ship at launch; Spanish, French and German are architected for
// but not yet enabled.
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../services/settings_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  void _select(BuildContext context, String code) {
    SettingsStore.shared.setLocale(Locale(code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).languageSaved)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsLanguage)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.outerPadding),
        children: [
          SectionHeader(l10n.languageAvailable),
          Card(
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'en',
                  groupValue: appLocaleNotifier.value.languageCode,
                  title: const Text('English'),
                  onChanged: (v) => _select(context, v!),
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  value: 'ro',
                  groupValue: appLocaleNotifier.value.languageCode,
                  title: const Text('Română'),
                  onChanged: (v) => _select(context, v!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SectionHeader(l10n.comingSoon),
          Card(
            child: Column(
              children: [
                for (final lang in const [
                  ('Español', 'es'),
                  ('Français', 'fr'),
                  ('Deutsch', 'de')
                ])
                  ListTile(
                    title: Text(lang.$1,
                        style: TextStyle(color: onSurface.withOpacity(0.4))),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: onSurface.withOpacity(0.2)),
                      ),
                      child: Text(
                        l10n.soon,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: onSurface.withOpacity(0.5)),
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
