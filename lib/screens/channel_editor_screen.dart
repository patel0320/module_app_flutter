// lib/screens/channel_editor_screen.dart
//
// Brief section 2.2 "Customization": rename an output and associate a
// simple icon with it, for quick and intuitive identification.
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ChannelEditorScreen extends StatefulWidget {
  const ChannelEditorScreen({super.key, required this.channel, required this.moduleName});

  final ChannelOutput channel;
  final String moduleName;

  @override
  State<ChannelEditorScreen> createState() => _ChannelEditorScreenState();
}

class _ChannelEditorScreenState extends State<ChannelEditorScreen> {
  late final TextEditingController _nameController = TextEditingController(text: widget.channel.name);
  late IconData _selectedIcon = widget.channel.icon;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final trimmed = _nameController.text.trim();
    widget.channel.name = trimmed.isEmpty ? widget.channel.name : trimmed;
    widget.channel.icon = _selectedIcon;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.channelEditorTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.outerPadding),
        children: [
          Text(widget.moduleName, style: TextStyle(color: onSurface.withOpacity(0.55))),
          const SizedBox(height: 16),
          Center(child: IconAvatar(icon: _selectedIcon, size: 72, filled: true)),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: l10n.channelNameLabel, prefixIcon: const Icon(Icons.label_outline)),
          ),
          const SizedBox(height: 24),
          SectionHeader(l10n.channelChooseIcon),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final icon in kChannelIconChoices)
                InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => setState(() => _selectedIcon = icon),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: icon == _selectedIcon ? onSurface : Colors.transparent,
                      border: Border.all(color: onSurface.withOpacity(icon == _selectedIcon ? 0 : 0.25)),
                    ),
                    child: Icon(icon, color: icon == _selectedIcon ? Theme.of(context).colorScheme.surface : onSurface),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton(onPressed: _save, child: Text(l10n.save)),
        ],
      ),
    );
  }
}
