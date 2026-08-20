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
import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'configuration_screen.dart' show openModuleDetail;
import 'manual_dimming_slider_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<DeviceModule> _modules = mockModules();
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
        MaterialPageRoute(builder: (_) => ManualDimmingSliderScreen(scenario: scenario)),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Running "${scenario.name}"...')),
    );
  }

  void _showRoomScenarios(Room room) {
    final scenarios = _allScenarios.where((s) => s.roomName == room.name).toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(room.name, style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'Scenarios in this room',
                style: TextStyle(color: Theme.of(sheetContext).colorScheme.onSurface.withOpacity(0.6)),
              ),
              const SizedBox(height: 8),
              if (scenarios.isEmpty)
                const EmptyState(icon: Icons.auto_awesome_outlined, message: 'No scenarios assigned to this room yet.')
              else
                for (final s in scenarios)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: IconAvatar(icon: s.icon),
                    title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(s.type == ScenarioType.manualSlider ? 'Manual dimming slider' : '${s.actions.length} action(s)'),
                    trailing: const Icon(Icons.chevron_right),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.outerPadding),
        children: [
          if (offline.isNotEmpty) ...[
            AlertBanner(
              icon: Icons.wifi_off_rounded,
              message: offline.length == 1
                  ? '${offline.first.name} is offline'
                  : '${offline.length} modules are offline',
              onTap: () => Navigator.of(context).pushNamed('/system-status'),
            ),
            const SizedBox(height: AppSpacing.betweenCards),
          ],
          if (overTemp.isNotEmpty) ...[
            AlertBanner(
              icon: Icons.thermostat,
              message: '${overTemp.first.name}: temperature out of range '
                  '(${overTemp.first.internalTempC.toStringAsFixed(1)}°C)',
              onTap: () => Navigator.of(context).pushNamed('/system-status'),
            ),
            const SizedBox(height: AppSpacing.betweenCards),
          ],
          const SectionHeader('Rooms'),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _rooms.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final room = _rooms[index];
                return OutlinedButton.icon(
                  onPressed: () => _showRoomScenarios(room),
                  icon: const Icon(Icons.meeting_room_outlined, size: 18),
                  label: Text(room.name),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          SectionHeader(
            'Quick Scenarios',
            trailing: Text(
              'Hold & drag to reorder',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
            ),
          ),
          if (_homeScenarios.isEmpty)
            const EmptyState(
              icon: Icons.auto_awesome_outlined,
              message: 'Enable "Show in Home" on a scenario to pin it here.',
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
                    padding: const EdgeInsets.only(bottom: AppSpacing.betweenCards),
                    child: _QuickScenarioCard(
                      index: i,
                      scenario: _homeScenarios[i],
                      onRun: () => _runScenario(_homeScenarios[i]),
                      onSliderChanged: (value) => setState(() => _homeScenarios[i].sliderValue = value),
                      onOpenSlider: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ManualDimmingSliderScreen(scenario: _homeScenarios[i])),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 24),
          const SectionHeader('Temperature Monitoring'),
          for (final module in _modules)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.betweenCards),
              child: _TemperatureRow(module: module, onTap: () => openModuleDetail(context, module)),
            ),
        ],
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
  });

  final int index;
  final Scenario scenario;
  final VoidCallback onRun;
  final ValueChanged<int> onSliderChanged;
  final VoidCallback onOpenSlider;

  @override
  Widget build(BuildContext context) {
    final isSlider = scenario.type == ScenarioType.manualSlider;
    return Card(
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
                    child: Icon(Icons.drag_indicator, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                  ),
                ),
                IconAvatar(icon: scenario.icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(scenario.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          RoomTag(label: scenario.roomName),
                          const SizedBox(width: 8),
                          Text(
                            isSlider ? 'Manual dimming' : '${scenario.actions.length} action(s)',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isSlider)
                  IconButton.outlined(onPressed: onOpenSlider, icon: const Icon(Icons.open_in_full))
                else
                  IconButton.filled(onPressed: onRun, icon: const Icon(Icons.play_arrow)),
              ],
            ),
            if (isSlider) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.brightness_low, size: 18),
                  Expanded(
                    child: Slider(
                      value: scenario.sliderValue.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 100,
                      onChanged: (v) => onSliderChanged(v.round()),
                    ),
                  ),
                  const Icon(Icons.brightness_high, size: 18),
                  SizedBox(width: 36, child: Text('${scenario.sliderValue}%', textAlign: TextAlign.end)),
                ],
              ),
            ],
          ],
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
    final bool alert = module.isOverTemperature;
    final Color onSurface = Theme.of(context).colorScheme.onSurface;
    final Color tempColor = alert ? AppColors.offlineAlert : onSurface;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.thermostat, color: tempColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(module.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${module.roomName} · range ${module.tempMinC.toStringAsFixed(0)}-${module.tempMaxC.toStringAsFixed(0)}°C',
                      style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.55)),
                    ),
                  ],
                ),
              ),
              Text(
                '${module.internalTempC.toStringAsFixed(1)}°C',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: tempColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
