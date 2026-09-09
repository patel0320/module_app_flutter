// lib/widgets/action_picker.dart
//
// Shared "Add Action" bottom sheet used by both the Scenario editor and the
// Automation editor, so a scenario/automation can control "one or more
// outputs, regardless of whether they belong to relay modules (ON/OFF) or
// dimmer modules (intensity control)" (brief section 2.4). It can also drive
// a module's virtual input (ON / OFF / Pulse), e.g. to trigger a physical
// input's associated output from a scenario.
import 'package:flutter/material.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';

import '../models/models.dart';

/// Shows a bottom sheet that lets the user pick a module and either an
/// output (relay ON/OFF or dimmer brightness) or an input (ON / OFF / Pulse),
/// returning the resulting [ScenarioAction], or null if the user cancelled.
///
/// When an [initial] action is provided the sheet pre-populates its fields
/// and behaves as an "edit" instead of "add".
Future<ScenarioAction?> showAddActionSheet(
  BuildContext context,
  List<DeviceModule> modules, {
  ScenarioAction? initial,
}) {
  final List<DeviceModule> outputModules =
      modules.where((m) => m.channels.isNotEmpty).toList();
  final List<DeviceModule> inputModules =
      modules.where((m) => m.inputs.isNotEmpty).toList();

  bool isInputTarget = initial?.isInputAction ?? false;
  DeviceModule? module;
  ChannelOutput? channel;
  PhysicalInput? input;
  bool turnOn = initial?.turnOn ?? true;
  int brightness = initial?.brightnessPct ?? 100;
  InputActionState inputState = initial?.inputState ?? InputActionState.on;

  if (initial != null) {
    if (isInputTarget) {
      module = _matchModule(inputModules, initial.moduleName) ??
          (inputModules.isNotEmpty ? inputModules.first : null);
      input = _matchInput(module?.inputs, initial.inputName);
    } else {
      module = _matchModule(outputModules, initial.moduleName) ??
          (outputModules.isNotEmpty ? outputModules.first : null);
      channel = _matchChannel(module?.channels, initial.channelName);
    }
  } else {
    module = outputModules.isNotEmpty ? outputModules.first : null;
    channel = module?.channels.first;
  }

  final bool isEditing = initial != null;

  return showModalBottomSheet<ScenarioAction>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          void switchTarget(bool toInput) {
            setSheetState(() {
              isInputTarget = toInput;
              module = toInput
                  ? (inputModules.isNotEmpty ? inputModules.first : null)
                  : (outputModules.isNotEmpty ? outputModules.first : null);
              channel = (toInput || module == null)
                  ? null
                  : module!.channels.first;
              input = (!toInput || module == null)
                  ? null
                  : module!.inputs.first;
            });
          }

          final bool isDimmer = !isInputTarget &&
              (module?.type == ModuleType.dimmerDc ||
                  module?.type == ModuleType.dimmerAc);
          final l10n = AppLocalizations.of(context);

          return SafeArea(
            child: Padding(
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
                  Text(l10n.actionPickerTargetLabel,
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        label: Text(l10n.actionPickerOutputTarget),
                        icon: const Icon(Icons.output_outlined),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text(l10n.actionPickerInputTarget),
                        icon: const Icon(Icons.touch_app_outlined),
                      ),
                    ],
                    selected: {isInputTarget},
                    onSelectionChanged: (s) => switchTarget(s.first),
                  ),
                  const SizedBox(height: 16),
                  if (isInputTarget)
                    if (inputModules.isEmpty)
                      Text(l10n.actionPickerNoInputs)
                    else ...[
                        DropdownButtonFormField<DeviceModule>(
                          initialValue: module,
                          decoration: InputDecoration(
                              labelText: l10n.actionPickerModuleLabel),
                          items: [
                            for (final m in inputModules)
                              DropdownMenuItem(value: m, child: Text(m.name)),
                          ],
                          onChanged: (m) => setSheetState(() {
                            module = m;
                            input = m?.inputs.first;
                          }),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<PhysicalInput>(
                          initialValue: input,
                          decoration: InputDecoration(
                              labelText: l10n.actionPickerInputLabel),
                          items: [
                            for (final i in module?.inputs ??
                                const <PhysicalInput>[])
                              DropdownMenuItem(
                                  value: i, child: Text(i.name)),
                          ],
                          onChanged: (i) => setSheetState(() => input = i),
                        ),
                        const SizedBox(height: 16),
                        Text(l10n.actionPickerState,
                            style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 8),
                        SegmentedButton<InputActionState>(
                          segments: [
                            ButtonSegment(
                                value: InputActionState.on,
                                label: Text(l10n.on)),
                            ButtonSegment(
                                value: InputActionState.off,
                                label: Text(l10n.off)),
                            ButtonSegment(
                                value: InputActionState.pulse,
                                label: Text(l10n.pulse)),
                          ],
                          selected: {inputState},
                          onSelectionChanged: (s) =>
                              setSheetState(() => inputState = s.first),
                        ),
                      ]
                  else if (outputModules.isEmpty)
                    Text(l10n.actionPickerNoOutputs)
                  else ...[
                    DropdownButtonFormField<DeviceModule>(
                      initialValue: module,
                      decoration: InputDecoration(
                          labelText: l10n.actionPickerModuleLabel),
                      items: [
                        for (final m in outputModules)
                          DropdownMenuItem(value: m, child: Text(m.name)),
                      ],
                      onChanged: (m) => setSheetState(() {
                        module = m;
                        channel = m?.channels.first;
                      }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ChannelOutput>(
                      initialValue: channel,
                      decoration: InputDecoration(
                          labelText: l10n.actionPickerOutputLabel),
                      items: [
                        for (final c in module?.channels ??
                            const <ChannelOutput>[])
                          DropdownMenuItem(value: c, child: Text(c.name)),
                      ],
                      onChanged: (c) => setSheetState(() => channel = c),
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
                          ButtonSegment(
                              value: true, label: Text(l10n.on)),
                          ButtonSegment(
                              value: false, label: Text(l10n.off)),
                        ],
                        selected: {turnOn},
                        onSelectionChanged: (s) =>
                            setSheetState(() => turnOn = s.first),
                      ),
                    ],
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: module == null ||
                            (isInputTarget
                                ? input == null
                                : channel == null)
                        ? null
                        : () => Navigator.pop(
                              context,
                              ScenarioAction(
                                moduleName: module!.name,
                                channelName: channel?.name ?? '',
                                icon: isInputTarget
                                    ? Icons.touch_app_outlined
                                    : channel!.icon,
                                isDimmerAction: isDimmer,
                                turnOn: turnOn,
                                brightnessPct: brightness,
                                isInputAction: isInputTarget,
                                inputName: input?.name ?? '',
                                inputState: inputState,
                              ),
                            ),
                    child: Text(isEditing
                        ? l10n.actionPickerSave
                        : l10n.actionPickerAdd),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

DeviceModule? _matchModule(List<DeviceModule> modules, String name) {
  for (final m in modules) {
    if (m.name == name) return m;
  }
  return null;
}

ChannelOutput? _matchChannel(List<ChannelOutput>? channels, String name) {
  for (final c in channels ?? const <ChannelOutput>[]) {
    if (c.name == name) return c;
  }
  return null;
}

PhysicalInput? _matchInput(List<PhysicalInput>? inputs, String name) {
  for (final i in inputs ?? const <PhysicalInput>[]) {
    if (i.name == name) return i;
  }
  return null;
}