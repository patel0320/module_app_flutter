// lib/widgets/action_picker.dart
//
// Shared "Add Action" bottom sheet used by both the Scenario editor and the
// Automation editor, so a scenario/automation can control "one or more
// outputs, regardless of whether they belong to relay modules (ON/OFF) or
// dimmer modules (intensity control)" (brief section 2.4).
import 'package:flutter/material.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';

import '../models/models.dart';

/// Shows a bottom sheet that lets the user pick a module + output and an
/// ON/OFF state (relay/blind) or a brightness percentage (dimmer). Returns
/// the resulting [ScenarioAction], or null if the user cancelled.
///
/// When an [initial] action is provided the sheet pre-populates its fields
/// and behaves as an "edit" instead of "add".
Future<ScenarioAction?> showAddActionSheet(
  BuildContext context,
  List<DeviceModule> modules, {
  ScenarioAction? initial,
}) {
  final List<DeviceModule> eligible =
      modules.where((m) => m.channels.isNotEmpty).toList();

  DeviceModule? selectedModule = eligible.isNotEmpty ? eligible.first : null;
  ChannelOutput? selectedChannel = selectedModule?.channels.first;
  bool turnOn = true;
  int brightness = 100;

  if (initial != null) {
    for (final m in eligible) {
      if (m.name == initial.moduleName) {
        selectedModule = m;
        break;
      }
    }
    selectedChannel = null;
    for (final c in selectedModule?.channels ?? const <ChannelOutput>[]) {
      if (c.name == initial.channelName) {
        selectedChannel = c;
        break;
      }
    }
    turnOn = initial.turnOn;
    brightness = initial.brightnessPct;
  }

  final bool isEditing = initial != null;

  return showModalBottomSheet<ScenarioAction>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final bool isDimmer = selectedModule?.type == ModuleType.dimmerDc ||
              selectedModule?.type == ModuleType.dimmerAc;
          final l10n = AppLocalizations.of(context);

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 20,
              bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    isEditing
                        ? l10n.actionPickerEditTitle
                        : l10n.actionPickerAddTitle,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                if (eligible.isEmpty)
                  Text(l10n.actionPickerNoOutputs)
                else ...[
                  DropdownButtonFormField<DeviceModule>(
                    value: selectedModule,
                    decoration: InputDecoration(
                        labelText: l10n.actionPickerModuleLabel),
                    items: [
                      for (final m in eligible)
                        DropdownMenuItem(value: m, child: Text(m.name)),
                    ],
                    onChanged: (m) => setSheetState(() {
                      selectedModule = m;
                      selectedChannel = m?.channels.first;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ChannelOutput>(
                    value: selectedChannel,
                    decoration: InputDecoration(
                        labelText: l10n.actionPickerOutputLabel),
                    items: [
                      for (final c in selectedModule?.channels ??
                          const <ChannelOutput>[])
                        DropdownMenuItem(value: c, child: Text(c.name)),
                    ],
                    onChanged: (c) => setSheetState(() => selectedChannel = c),
                  ),
                  const SizedBox(height: 16),
                  if (isDimmer) ...[
                    Text(l10n.actionPickerBrightness(brightness),
                        style: Theme.of(context).textTheme.bodyLarge),
                    Slider(
                      value: brightness.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: '$brightness%',
                      onChanged: (v) =>
                          setSheetState(() => brightness = v.round()),
                    ),
                  ] else ...[
                    Text(l10n.actionPickerState,
                        style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(value: true, label: Text(l10n.on)),
                        ButtonSegment(value: false, label: Text(l10n.off)),
                      ],
                      selected: {turnOn},
                      onSelectionChanged: (s) =>
                          setSheetState(() => turnOn = s.first),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: selectedModule == null || selectedChannel == null
                        ? null
                        : () => Navigator.pop(
                              context,
                              ScenarioAction(
                                moduleName: selectedModule!.name,
                                channelName: selectedChannel!.name,
                                icon: selectedChannel!.icon,
                                isDimmerAction: isDimmer,
                                turnOn: turnOn,
                                brightnessPct: brightness,
                              ),
                            ),
                    child: Text(isEditing
                        ? l10n.actionPickerSave
                        : l10n.actionPickerAdd),
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}
