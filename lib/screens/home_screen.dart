// lib/screens/home_screen.dart
//
// Brief section I "Home Section":
//  1. Quick access to scenarios flagged "Show in Home", reorderable by drag
//     and drop.
//  2. A prominent red banner when a module is offline, tapping it opens the
//     System Status page.
//  3. Real-time internal temperature monitoring per module with a similar
//     alert banner when thresholds are exceeded.
// Rooms (brief 2.5) are also surfaced here for quick access to their
// scenario groups.
//
// Visual language: styled entirely through the app theme
// (lib/theme/app_theme.dart) via Theme.of(context). Cards use the themed
// glass Card look and accents come from the active SmartHome palette, so this
// screen matches every other screen in the app. Offline/temperature semantics
// stay green/red for consistency.
import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../services/module_store.dart';
import '../theme/app_theme.dart';
import '../theme/theme_palettes.dart';
import '../widgets/common_widgets.dart';
import 'configuration_screen.dart' show openModuleDetail;
import 'manual_dimming_slider_screen.dart';
import 'scenario_editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// The fleet is read from the app-wide [ModuleStore] so live status
  /// (online/offline, temperature) refreshed on open is reflected here.
  List<DeviceModule> get _modules => ModuleStore.shared.modules;
  final List<Room> _rooms = mockRooms();

  /// Single source of truth for scenarios; the Home quick-access list below
  /// is a filtered *view* over this same list of object references, so
  /// slider edits made from a Home card stay consistent with the room
  /// bottom sheet within this screen's lifetime.
  late final List<Scenario> _allScenarios = mockScenarios();
  late final List<Scenario> _homeScenarios =
      _allScenarios.where((s) => s.showInHome).toList();

  List<DeviceModule> get _offlineModules =>
      _modules.where((m) => m.status == ConnectionStatus.offline).toList();

  List<DeviceModule> get _overTempModules =>
      _modules.where((m) => m.isOverTemperature).toList();

  void _onReorderHomeScenarios(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _homeScenarios.removeAt(oldIndex);
      _homeScenarios.insert(newIndex, item);
    });
  }

  void _runScenario(Scenario scenario) {
    if (scenario.type == ScenarioType.manualSlider) {
      Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => ManualDimmingSliderScreen(scenario: scenario)),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Running "${scenario.name}"...')),
    );
  }

  void _showRoomScenarios(Room room) {
    final scenarios =
        _allScenarios.where((s) => s.roomName == room.name).toList();
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      barrierColor: Colors.black.withOpacity(0.4),
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Greeting(room.name,
                        subtitle: 'Scenarios · ${scenarios.length}'),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (scenarios.isEmpty)
                const EmptyState(
                    icon: Icons.auto_awesome_outlined,
                    message: 'No scenarios assigned to this room yet.')
              else
                for (final s in scenarios)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: IconAvatar(icon: s.icon),
                    title: Text(s.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      s.type == ScenarioType.manualSlider
                          ? 'Manual dimming slider'
                          : '${s.actions.length} action(s)',
                      style: TextStyle(
                          color: cs.onSurface.withOpacity(0.6), fontSize: 13),
                    ),
                    trailing:
                        Icon(Icons.chevron_right,
                            color: cs.onSurface.withOpacity(0.6)),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _runScenario(s);
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offline = _offlineModules;
    final overTemp = _overTempModules;
    final onlineCount = _modules.length - offline.length;
    final cs = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: ModuleStore.shared,
      builder: (context, _) => Scaffold(
      body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header / deck title.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: _Greeting(
                        'Home',
                        subtitle:
                            '$onlineCount/${_modules.length} modules online',
                      ),
                    ),
                    _StatusPill(officers: onlineCount, total: _modules.length),
                    const SizedBox(width: 10),
                    const _ThemeSwitcherButton(),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    if (offline.isNotEmpty) ...[
                      _AlertBanner(
                        icon: Icons.wifi_off_rounded,
                        message: offline.length == 1
                            ? '${offline.first.name} is offline'
                            : '${offline.length} modules are offline',
                        onTap: () =>
                            Navigator.of(context).pushNamed('/system-status'),
                      ),
                      const SizedBox(height: AppSpacing.betweenCards),
                    ],
                    if (overTemp.isNotEmpty) ...[
                      _AlertBanner(
                        icon: Icons.thermostat,
                        message:
                            '${overTemp.first.name}: temperature out of range '
                            '(${overTemp.first.internalTempC.toStringAsFixed(1)}°C)',
                        onTap: () =>
                            Navigator.of(context).pushNamed('/system-status'),
                      ),
                      const SizedBox(height: AppSpacing.betweenCards),
                    ],
                    const SizedBox(height: 12),
                    const _SectionLabel('Rooms'),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 56,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _rooms.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final room = _rooms[index];
                          return _RoomChip(
                              room: room,
                              onTap: () => _showRoomScenarios(room));
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(
                            child: _SectionLabel('Quick Scenarios')),
                        Text(
                          'Hold & drag to reorder',
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withOpacity(0.6)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_homeScenarios.isEmpty)
                      const EmptyState(
                        icon: Icons.auto_awesome_outlined,
                        message:
                            'Enable "Show in Home" on a scenario to pin it here.',
                      )
                    else
                      ReorderableListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        onReorder: _onReorderHomeScenarios,
                        children: [
                          for (int i = 0; i < _homeScenarios.length; i++)
                            Padding(
                              key: ValueKey(_homeScenarios[i].id),
                              padding: const EdgeInsets.only(
                                  bottom: AppSpacing.betweenCards),
                              child: _QuickScenarioCard(
                                index: i,
                                scenario: _homeScenarios[i],
                                onRun: () => _runScenario(_homeScenarios[i]),
                                onSliderChanged: (value) => setState(() =>
                                    _homeScenarios[i].sliderValue = value),
                                onOpenSlider: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => ManualDimmingSliderScreen(
                                          scenario: _homeScenarios[i])),
                                ),
                                onEdit: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ScenarioEditorScreen(
                                        scenario: _homeScenarios[i]),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    const _SectionLabel('Temperature Monitoring'),
                    const SizedBox(height: 10),
                    for (final module in _modules)
                      Padding(
                        padding: const EdgeInsets.only(
                            bottom: AppSpacing.betweenCards),
                        child: _TemperatureRow(
                            module: module,
                            onTap: () => openModuleDetail(context, module)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Uppercase, wide-tracked section label (replaces AuroraSectionLabel).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: cs.onSurface.withOpacity(0.65),
      ),
    );
  }
}

/// Hero greeting line used as the Home screen's deck title (replaces
/// AuroraGreeting).
class _Greeting extends StatelessWidget {
  const _Greeting(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: cs.onSurface.withOpacity(0.92),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6)),
          ),
        ],
      ],
    );
  }
}

/// Compact online/offline summary pill shown in the Home header.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.officers, required this.total});

  final int officers;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool allOk = officers == total;
    return Card(
      color: cs.primary.withOpacity(0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(100),
        side: BorderSide(
          color: allOk ? cs.primary.withOpacity(0.4) : cs.error.withOpacity(0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GlowDot(color: allOk ? AppColors.online : AppColors.offlineAlert),
            const SizedBox(width: 8),
            Text(
              '$officers/$total',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: allOk ? cs.primary : cs.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small glowing status dot (green = all online, red = some offline).
class _GlowDot extends StatelessWidget {
  const _GlowDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    const double size = 8;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.6), blurRadius: 6, spreadRadius: 1)
        ],
      ),
    );
  }
}

/// Red alert banner (offline / over-temperature) that opens System Status on
/// tap -- the same prominent treatment for both alerts.
class _AlertBanner extends StatelessWidget {
  const _AlertBanner(
      {required this.icon, required this.message, required this.onTap});

  final IconData icon;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.error.withOpacity(0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.error.withOpacity(0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: cs.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                      color: cs.error, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              Icon(Icons.chevron_right, color: cs.error),
            ],
          ),
        ),
      ),
    );
  }
}

/// A touch-sized glass chip for each room's quick access (>=48dp tall).
class _RoomChip extends StatelessWidget {
  const _RoomChip({required this.room, required this.onTap});

  final Room room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.meeting_room_outlined, color: cs.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                room.name,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: cs.onSurface),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right,
                  color: cs.onSurface.withOpacity(0.6), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickScenarioCard extends StatelessWidget {
  const _QuickScenarioCard({
    required this.index,
    required this.scenario,
    required this.onRun,
    required this.onSliderChanged,
    required this.onOpenSlider,
    required this.onEdit,
  });

  final int index;
  final Scenario scenario;
  final VoidCallback onRun;
  final ValueChanged<int> onSliderChanged;
  final VoidCallback onOpenSlider;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSlider = scenario.type == ScenarioType.manualSlider;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(Icons.drag_indicator,
                          color: cs.onSurface.withOpacity(0.6), size: 22),
                    ),
                  ),
                  _ScenarioAvatar(
                      icon: scenario.icon,
                      tint: isSlider ? cs.primary : cs.onSurface),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scenario.name,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: cs.onSurface),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _RoomTag(label: scenario.roomName),
                            const SizedBox(width: 8),
                            Text(
                              isSlider
                                  ? 'Manual dimming'
                                  : '${scenario.actions.length} action(s)',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withOpacity(0.6)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isSlider)
                    _IconActionButton(
                      icon: const Icon(Icons.open_in_full, size: 20),
                      onTap: onOpenSlider,
                      outlined: true,
                    )
                  else
                    _RunButton(onTap: onRun),
                ],
              ),
              if (isSlider) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: Row(
                    children: [
                      Icon(Icons.brightness_low,
                          size: 18, color: cs.onSurface.withOpacity(0.6)),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: cs.primary,
                            inactiveTrackColor: cs.onSurface.withOpacity(0.14),
                            thumbColor: cs.primary,
                            overlayColor: cs.primary.withOpacity(0.15),
                            valueIndicatorColor: cs.primary,
                            valueIndicatorTextStyle: TextStyle(
                                color: cs.onPrimary,
                                fontWeight: FontWeight.w700),
                          ),
                          child: Slider(
                            value: scenario.sliderValue.toDouble(),
                            min: 0,
                            max: 100,
                            divisions: 100,
                            label: '${scenario.sliderValue}%',
                            onChanged: (v) => onSliderChanged(v.round()),
                          ),
                        ),
                      ),
                      Icon(Icons.brightness_high,
                          size: 18, color: cs.onSurface.withOpacity(0.6)),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${scenario.sliderValue}%',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: cs.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Scenario icon avatar; slider icons get a mint halo echoing the reference's
/// primary-glow wash.
class _ScenarioAvatar extends StatelessWidget {
  const _ScenarioAvatar({required this.icon, required this.tint});

  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tint.withOpacity(0.12),
        border: Border.all(color: tint.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: tint.withOpacity(0.18), blurRadius: 12)],
      ),
      child: Icon(icon, color: tint, size: 22),
    );
  }
}

/// Inline room tag, restyled to match the glass chips.
class _RoomTag extends StatelessWidget {
  const _RoomTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: cs.onSurface.withOpacity(0.06),
        border: Border.all(color: cs.onSurface.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withOpacity(0.6)),
      ),
    );
  }
}

/// Primary-accent "run / play" button.
class _RunButton extends StatelessWidget {
  const _RunButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: Ink(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
              colors: [cs.primary, cs.primary]),
          boxShadow: [
            BoxShadow(color: cs.primary.withOpacity(0.4), blurRadius: 14),
          ],
        ),
        width: 52,
        height: 52,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Icon(Icons.play_arrow_rounded, color: cs.onPrimary, size: 30),
        ),
      ),
    );
  }
}

/// Secondary outlined icon action (e.g. open slider in full screen).
class _IconActionButton extends StatelessWidget {
  const _IconActionButton(
      {required this.icon, required this.onTap, required this.outlined});

  final Widget icon;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: Ink(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: outlined ? cs.onSurface.withOpacity(0.08) : null,
          border: outlined
              ? Border.all(color: cs.onSurface.withOpacity(0.25))
              : null,
          gradient: outlined
              ? null
              : LinearGradient(colors: [cs.primary, cs.primary]),
        ),
        width: 48,
        height: 48,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
              child: outlined
                  ? Icon(Icons.open_in_full, color: cs.onSurface, size: 20)
                  : icon),
        ),
      ),
    );
  }
}

class _TemperatureRow extends StatelessWidget {
  const _TemperatureRow({required this.module, required this.onTap});

  final DeviceModule module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool alert = module.isOverTemperature;
    final Color valueColor = alert ? cs.error : cs.primary;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: valueColor.withOpacity(0.12),
                  border: Border.all(color: valueColor.withOpacity(0.4)),
                ),
                child: Icon(Icons.thermostat, color: valueColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(module.name,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: cs.onSurface)),
                    const SizedBox(height: 2),
                    Text(
                      '${module.roomName} · range ${module.tempMinC.toStringAsFixed(0)}-${module.tempMaxC.toStringAsFixed(0)}°C',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurface.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
              Text(
                '${module.internalTempC.toStringAsFixed(1)}°C',
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: valueColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header button that opens the multi-theme palette picker.
class _ThemeSwitcherButton extends StatelessWidget {
  const _ThemeSwitcherButton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: () => _openPicker(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Icon(Icons.palette_outlined, color: cs.primary, size: 20),
        ),
      ),
    );
  }

  void _openPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          _ThemePickerSheet(selected: homeThemeIdNotifier.value),
    );
  }
}

/// Bottom sheet listing every theme from [HomeThemePalettes], letting the user
/// swap palettes live on the Home screen.
class _ThemePickerSheet extends StatelessWidget {
  const _ThemePickerSheet({required this.selected});

  final HomeThemeId selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          elevation: 6,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('Theme'),
                const SizedBox(height: 6),
                Text(
                  'Choose a color palette for the deck.',
                  style:
                      TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 13),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: HomeThemePalettes.all.length,
                    itemBuilder: (context, index) {
                      final palette = HomeThemePalettes.all[index];
                      return _ThemeTile(
                        palette: palette,
                        selected: palette.id == selected,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One selectable row in the theme picker, with a live gradient swatch.
class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.palette, required this.selected});

  final HomePalette palette;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final List<Color> swatch = palette.backgroundGradient.colors;
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: selected ? cs.primary.withOpacity(0.12) : null,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [swatch.first, swatch.last],
          ),
          border: Border.all(color: palette.panelBorder),
        ),
        child: Icon(palette.icon, color: palette.primary, size: 22),
      ),
      title: Text(
        palette.name,
        style: TextStyle(
          color: cs.onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_circle, color: cs.primary)
          : Icon(Icons.circle_outlined, color: cs.onSurface.withOpacity(0.6)),
      onTap: () {
        homeThemeIdNotifier.value = palette.id;
        Navigator.pop(context);
      },
    );
  }
}
