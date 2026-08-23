// lib/screens/scenarios_screen.dart
//
// Brief section 2.4 "Automations and Scenarios (Scenes)": the list of
// tap-to-run scenarios (and the manual dimming slider), with quick access
// to Automations, Rooms and the Event History.
import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'manual_dimming_slider_screen.dart';
import 'scenario_editor_screen.dart';

class ScenariosScreen extends StatefulWidget {
  const ScenariosScreen({super.key});

  @override
  State<ScenariosScreen> createState() => _ScenariosScreenState();
}

class _ScenariosScreenState extends State<ScenariosScreen> {
  final List<Scenario> _scenarios = mockScenarios();

  void _runScenario(Scenario scenario) {
    if (scenario.type == ScenarioType.manualSlider) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ManualDimmingSliderScreen(scenario: scenario)));
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Running "${scenario.name}"...')));
  }

  Future<void> _createScenario() async {
    final Scenario? created = await Navigator.of(context).push<Scenario>(
      MaterialPageRoute(builder: (_) => const ScenarioEditorScreen()),
    );
    if (created != null) setState(() => _scenarios.add(created));
  }

  Future<void> _editScenario(Scenario scenario) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => ScenarioEditorScreen(scenario: scenario)),
    );
    setState(() {});
  }

  Future<void> _deleteScenario(Scenario scenario) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete scenario',
      message: 'Delete "${scenario.name}"? This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (confirmed) setState(() => _scenarios.remove(scenario));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scenarios'),
        actions: [
          IconButton(
            tooltip: 'Rooms',
            icon: const Icon(Icons.meeting_room_outlined),
            onPressed: () => Navigator.of(context).pushNamed('/rooms'),
          ),
          IconButton(
            tooltip: 'Automations',
            icon: const Icon(Icons.rule_outlined),
            onPressed: () => Navigator.of(context).pushNamed('/automations'),
          ),
          IconButton(
            tooltip: 'Event history',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).pushNamed('/event-history'),
          ),
        ],
      ),
      body: _scenarios.isEmpty
          ? const EmptyState(
              icon: Icons.auto_awesome_outlined,
              message: 'No scenarios yet. Create your first one.')
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.outerPadding),
              itemCount: _scenarios.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.betweenCards),
              itemBuilder: (context, index) {
                final scenario = _scenarios[index];
                return _ScenarioCard(
                  scenario: scenario,
                  onRun: () => _runScenario(scenario),
                  onEdit: () => _editScenario(scenario),
                  onDelete: () => _deleteScenario(scenario),
                  onShowInHomeChanged: (v) =>
                      setState(() => scenario.showInHome = v),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _createScenario,
        icon: const Icon(Icons.add),
        label: const Text('New scenario', style: AppTheme.fabLabelStyle),
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.scenario,
    required this.onRun,
    required this.onEdit,
    required this.onDelete,
    required this.onShowInHomeChanged,
  });

  final Scenario scenario;
  final VoidCallback onRun;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onShowInHomeChanged;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final bool isSlider = scenario.type == ScenarioType.manualSlider;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconAvatar(icon: scenario.icon),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(scenario.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            RoomTag(label: scenario.roomName),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isSlider
                                    ? 'Manual dimming slider'
                                    : '${scenario.actions.length} action(s)',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: onSurface.withOpacity(0.55)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.outlined(
                      onPressed: onRun,
                      icon: Icon(
                          isSlider ? Icons.open_in_full : Icons.play_arrow)),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Show on Home',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Switch(
                      value: scenario.showInHome,
                      onChanged: onShowInHomeChanged),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
