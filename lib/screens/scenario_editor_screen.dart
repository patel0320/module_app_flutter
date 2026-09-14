// lib/screens/scenario_editor_screen.dart
//
// Brief section 2.4 "Automations and Scenarios": create or edit a
// tap-to-run scenario (multiple ON/OFF or brightness actions) or a
// dedicated "Manual dimming Slider" scenario controlling a single dimmer
// output.
import 'package:flutter/material.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../services/custom_color_store.dart';
import '../services/module_store.dart';
import '../services/room_store.dart';
import '../theme/app_theme.dart';
import '../widgets/action_picker.dart';
import '../widgets/common_widgets.dart';

class ScenarioEditorScreen extends StatefulWidget {
  const ScenarioEditorScreen({super.key, this.scenario});

  /// Null when creating a brand new scenario.
  final Scenario? scenario;

  @override
  State<ScenarioEditorScreen> createState() => _ScenarioEditorScreenState();
}

class _ScenarioEditorScreenState extends State<ScenarioEditorScreen> {
  late final bool _isNew = widget.scenario == null;
  late final TextEditingController _nameController =
      TextEditingController(text: widget.scenario?.name ?? '');
  late IconData _icon = widget.scenario?.icon ?? Icons.auto_awesome_outlined;
  late String _roomName = widget.scenario?.roomName ?? 'General';
  late bool _showInHome = widget.scenario?.showInHome ?? false;
  late Color? _backgroundColor = widget.scenario?.backgroundColor;
  late ScenarioType _type = widget.scenario?.type ?? ScenarioType.tapToRun;
  late final List<ScenarioAction> _actions =
      List.of(widget.scenario?.actions ?? const []);
  late String _sliderTargetName = widget.scenario?.sliderTargetName ?? '';
  late int _sliderValue = widget.scenario?.sliderValue ?? 50;

  List<DeviceModule> _modules = const [];
  List<Room> _rooms = const [];
  List<Color> _savedColors = const [];

  List<String> get _dimmerTargets => [
        for (final m in _modules.where((m) =>
            m.type == ModuleType.dimmerDc || m.type == ModuleType.dimmerAc))
          for (final c in m.channels) '${c.name} - ${m.name}',
      ];

  @override
  void initState() {
    super.initState();
    ModuleStore.shared.init().then((_) {
      if (!mounted) return;
      setState(() => _modules = ModuleStore.shared.modules);
    });
    RoomStore.shared.init().then((_) {
      if (!mounted) return;
      setState(() => _rooms = RoomStore.shared.rooms);
    });
    CustomColorStore.shared.init().then((_) {
      if (!mounted) return;
      setState(() => _savedColors = CustomColorStore.shared.colors);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final IconData? picked = await showModalBottomSheet<IconData>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final icon in kChannelIconChoices)
                InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => Navigator.pop(context, icon),
                  child: CircleAvatar(radius: 26, child: Icon(icon)),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _icon = picked);
  }

  Future<void> _addAction() async {
    final action = await showAddActionSheet(context, _modules);
    if (action != null) setState(() => _actions.add(action));
  }

  Future<void> _editAction(int index) async {
    final action =
        await showAddActionSheet(context, _modules, initial: _actions[index]);
    if (action != null) setState(() => _actions[index] = action);
  }

  Future<void> _pickCustomColor() async {
    final Color? picked = await showModalBottomSheet<Color>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      builder: (_) => _ColorPickerSheet(
        initial: _backgroundColor ?? kScenarioBackgroundPresets.first,
      ),
    );
    if (!mounted) return;
    // Reflect any colors saved inside the picker sheet even when it was
    // dismissed without confirming.
    setState(() => _savedColors = CustomColorStore.shared.colors);
    if (picked != null) setState(() => _backgroundColor = picked);
  }

  Future<void> _deleteSavedColor(Color color) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.scenarioColorRemoveTitle,
      message: l10n.scenarioColorRemoveMsg,
      confirmLabel: l10n.delete,
    );
    if (!confirmed) return;
    await CustomColorStore.shared.remove(color);
    if (!mounted) return;
    setState(() {
      _savedColors = CustomColorStore.shared.colors;
      if (_backgroundColor == color) _backgroundColor = null;
    });
  }

  void _save() {
    FocusScope.of(context).unfocus();
    final String name = _nameController.text.trim().isEmpty
        ? AppLocalizations.of(context).scenarioUntitled
        : _nameController.text.trim();
    if (widget.scenario != null) {
      final s = widget.scenario!;
      s.name = name;
      s.icon = _icon;
      s.roomName = _roomName;
      s.showInHome = _showInHome;
      s.backgroundColor = _backgroundColor;
      s.type = _type;
      s.actions
        ..clear()
        ..addAll(_actions);
      s.sliderTargetName = _sliderTargetName;
      s.sliderValue = _sliderValue;
      Navigator.of(context).pop(s);
    } else {
      final s = Scenario(
        id: 'scenario-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        icon: _icon,
        type: _type,
        roomName: _roomName,
        showInHome: _showInHome,
        backgroundColor: _backgroundColor,
        actions: _actions,
        sliderTargetName: _sliderTargetName,
        sliderValue: _sliderValue,
      );
      Navigator.of(context).pop(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final l10n = AppLocalizations.of(context);
    final roomOptions = ['General', ..._rooms.map((r) => r.name)];
    final dimmerTargets = _dimmerTargets;
    final sliderTarget = dimmerTargetChannel(_modules, _sliderTargetName);

    return Scaffold(
      appBar: AppBar(
          title: Text(_isNew ? l10n.scenarioNewTitle : l10n.scenarioEditTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.outerPadding),
          children: [
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(48),
                onTap: _pickIcon,
                child: Stack(
                  children: [
                    IconAvatar(icon: _icon, size: 84, filled: true),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor:
                            Theme.of(context).scaffoldBackgroundColor,
                        child: Icon(Icons.edit, size: 14, color: onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                  labelText: l10n.scenarioNameLabel,
                  prefixIcon: const Icon(Icons.label_outline)),
            ),
            const SizedBox(height: 20),
            SectionHeader(l10n.scenarioTypeSection),
            SegmentedButton<ScenarioType>(
              segments: [
                ButtonSegment(
                    value: ScenarioType.tapToRun,
                    label: Text(l10n.scenarioTypeTapToRun),
                    icon: const Icon(Icons.touch_app_outlined)),
                ButtonSegment(
                    value: ScenarioType.manualSlider,
                    label: Text(l10n.scenarioTypeManualSlider),
                    icon: const Icon(Icons.tune)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: roomOptions.contains(_roomName)
                  ? _roomName
                  : roomOptions.first,
              decoration: InputDecoration(
                  labelText: l10n.scenarioRoomLabel,
                  prefixIcon: const Icon(Icons.meeting_room_outlined)),
              items: [
                for (final room in roomOptions)
                  DropdownMenuItem(value: room, child: Text(room))
              ],
              onChanged: (value) =>
                  setState(() => _roomName = value ?? _roomName),
            ),
            const SizedBox(height: 20),
            SectionHeader(l10n.scenarioBackgroundSection),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ColorSwatch(
                  label: l10n.scenarioBackgroundDefault,
                  color: null,
                  selected: _backgroundColor == null,
                  onTap: () => setState(() => _backgroundColor = null),
                ),
                for (final preset in kScenarioBackgroundPresets)
                  _ColorSwatch(
                    color: preset,
                    selected: _backgroundColor == preset,
                    onTap: () => setState(() => _backgroundColor = preset),
                  ),
                for (final saved in _savedColors)
                  _ColorSwatch(
                    color: saved,
                    selected: _backgroundColor == saved,
                    onTap: () => setState(() => _backgroundColor = saved),
                    onLongPress: () => _deleteSavedColor(saved),
                  ),
                _ColorSwatch(
                  label: l10n.scenarioBackgroundCustom,
                  color: _backgroundColor == null ||
                          kScenarioBackgroundPresets.contains(_backgroundColor)
                      ? const Color(0xFFB0BEC5)
                      : _backgroundColor,
                  selected: _backgroundColor != null &&
                      !kScenarioBackgroundPresets.contains(_backgroundColor),
                  onTap: _pickCustomColor,
                ),
              ],
            ),
            if (_savedColors.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                l10n.scenarioBackgroundSavedHint,
                style: TextStyle(
                    fontSize: 12, color: onSurface.withValues(alpha: 0.5)),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.showOnHome),
              subtitle: Text(l10n.scenarioPinHint),
              value: _showInHome,
              onChanged: (v) => setState(() => _showInHome = v),
            ),
            const SizedBox(height: 12),
            if (_type == ScenarioType.tapToRun) ...[
              SectionHeader(
                l10n.scenarioActionsSection,
                trailing: TextButton.icon(
                    onPressed: _addAction,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.add)),
              ),
              if (_actions.isEmpty)
                EmptyState(
                    icon: Icons.flash_on_outlined,
                    message: l10n.scenarioActionsEmpty)
              else
                for (int i = 0; i < _actions.length; i++)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppSpacing.betweenCards),
                    child: Card(
                      child: ListTile(
                        leading: IconAvatar(icon: _actions[i].icon),
                        title: Text(
                            _actions[i].isInputAction
                                ? _actions[i].inputName
                                : _actions[i].channelName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(l10n.scenarioActionModuleSummary(
                            _actions[i].moduleName, _actions[i].summary)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: l10n.scenarioEditActionTooltip,
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _editAction(i),
                            ),
                            IconButton(
                              tooltip: l10n.scenarioDeleteActionTooltip,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  setState(() => _actions.removeAt(i)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ] else ...[
              SectionHeader(l10n.scenarioSliderTargetSection),
              DropdownButtonFormField<String>(
                initialValue: dimmerTargets.contains(_sliderTargetName)
                    ? _sliderTargetName
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                    labelText: l10n.scenarioDimmerOutputLabel,
                    prefixIcon: const Icon(Icons.lightbulb_outline)),
                items: [
                  for (final t in dimmerTargets)
                    DropdownMenuItem(
                        value: t,
                        child: Text(t,
                            maxLines: 1, overflow: TextOverflow.ellipsis))
                ],
                selectedItemBuilder: (context) => [
                  for (final t in dimmerTargets)
                    Align(
                      alignment: Alignment.centerLeft,
                      child:
                          Text(t, maxLines: 1, overflow: TextOverflow.ellipsis),
                    )
                ],
                onChanged: (value) => setState(
                    () => _sliderTargetName = value ?? _sliderTargetName),
              ),
              const SizedBox(height: 16),
              Text(l10n.scenarioDefaultBrightness(_sliderValue),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Slider(
                value: _sliderValue.toDouble(),
                min: 0,
                max: 100,
                divisions: sliderTarget?.brightnessSliderDivisions ?? 100,
                label: '$_sliderValue%',
                onChanged: sliderTarget == null
                    ? null
                    : (v) => setState(() =>
                        _sliderValue = sliderTarget.snapBrightness(v.round())),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: Text(l10n.scenarioSave)),
          ],
        ),
      ),
    );
  }
}

/// A round, tappable color choice for a scenario's background. [color] being
/// null renders the "Default" swatch (plain themed surface). Selected swatches
/// get a primary ring plus a contrast-aware check mark.
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.color,
    this.label,
  });

  final bool selected;
  final VoidCallback onTap;

  /// Optional long-press affordance (used to delete a saved custom color).
  final VoidCallback? onLongPress;
  final Color? color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const double size = 48;
    final Color fill = color ??
        (Theme.of(context).brightness == Brightness.dark
            ? cs.surfaceContainerHigh
            : cs.surfaceContainerHighest);
    final bool light =
        ThemeData.estimateBrightnessForColor(fill) == Brightness.light;
    return InkWell(
      borderRadius: BorderRadius.circular(size / 2),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(
                color: selected
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.25),
                width: selected ? 3 : 1,
              ),
            ),
            child: selected
                ? Icon(
                    Icons.check,
                    size: 22,
                    color: light ? Colors.black87 : Colors.white,
                  )
                : null,
          ),
          if (label != null) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: 64,
              child: Text(
                label!,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: cs.onSurface.withValues(alpha: selected ? 1 : 0.6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottom sheet with a minimal HSV color picker: a live preview plus hue,
/// saturation and brightness sliders. Popping with the check button returns
/// the currently previewed color.
class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({required this.initial});

  final Color initial;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final Color current = _hsv.toColor();
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.scenarioBackgroundPickerTitle,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton.filled(
                onPressed: () => Navigator.pop(context, current),
                icon: const Icon(Icons.check),
                tooltip: l10n.scenarioSave,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: current,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.onSurface.withValues(alpha: 0.2)),
            ),
          ),
          const SizedBox(height: 20),
          _PickerSlider(
            label: l10n.scenarioBackgroundHue,
            value: _hsv.hue,
            max: 360,
            onChanged: (v) => setState(() => _hsv = _hsv.withHue(v)),
          ),
          _PickerSlider(
            label: l10n.scenarioBackgroundSaturation,
            value: _hsv.saturation,
            max: 1,
            onChanged: (v) => setState(() => _hsv = _hsv.withSaturation(v)),
          ),
          _PickerSlider(
            label: l10n.scenarioBackgroundValue,
            value: _hsv.value,
            max: 1,
            onChanged: (v) => setState(() => _hsv = _hsv.withValue(v)),
          ),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: _saveColor,
            icon: Icon(CustomColorStore.shared.contains(current)
                ? Icons.bookmark_added
                : Icons.bookmark_add_outlined),
            label: Text(
              CustomColorStore.shared.contains(current)
                  ? l10n.scenarioColorAlreadySaved
                  : l10n.scenarioColorPickerSave,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveColor() async {
    final l10n = AppLocalizations.of(context);
    final Color color = _hsv.toColor();
    final bool added = await CustomColorStore.shared.add(color);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(added
          ? l10n.scenarioColorSaved
          : CustomColorStore.shared.contains(color)
              ? l10n.scenarioColorAlreadySaved
              : l10n.scenarioColorLimit(CustomColorStore.shared.maxColors)),
    ));
  }
}

class _PickerSlider extends StatelessWidget {
  const _PickerSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(0, max).toDouble(),
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
