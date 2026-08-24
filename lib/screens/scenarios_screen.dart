// lib/screens/scenarios_screen.dart
//
// Brief section 2.4 "Automations and Scenarios (Scenes)": the list of
// tap-to-run scenarios (and the manual dimming slider), with quick access
// to Automations, Rooms and the Event History.
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/scenario_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'manual_dimming_slider_screen.dart';
import 'scenario_editor_screen.dart';

class ScenariosScreen extends StatelessWidget {
  const ScenariosScreen({super.key});

  static final ScenarioStore _store = ScenarioStore.shared;

  void _runScenario(BuildContext context, Scenario scenario) {
    if (scenario.type == ScenarioType.manualSlider) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ManualDimmingSliderScreen(scenario: scenario)));
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Running "${scenario.name}"...')));
  }

  Future<void> _createScenario(BuildContext context) async {
    final Scenario? created = await Navigator.of(context).push<Scenario>(
      MaterialPageRoute(builder: (_) => const ScenarioEditorScreen()),
    );
    if (created != null) await _store.upsert(created);
  }

  Future<void> _editScenario(BuildContext context, Scenario scenario) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => ScenarioEditorScreen(scenario: scenario)),
    );
    await _store.commit();
  }

  Future<void> _deleteScenario(
      BuildContext context, Scenario scenario) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete scenario',
      message: 'Delete "${scenario.name}"? This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (confirmed) await _store.remove(scenario.id);
  }

  Future<void> _setShowInHome(Scenario scenario, bool value) async {
    scenario.showInHome = value;
    await _store.commit();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final scenarios = _store.scenarios;
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
                onPressed: () =>
                    Navigator.of(context).pushNamed('/automations'),
              ),
              IconButton(
                tooltip: 'Event history',
                icon: const Icon(Icons.history),
                onPressed: () =>
                    Navigator.of(context).pushNamed('/event-history'),
              ),
            ],
          ),
          body: scenarios.isEmpty
              ? const Center(
                  child: EmptyState(
                    icon: Icons.auto_awesome_outlined,
                    message: 'No scenarios yet. Create your first one.',
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.outerPadding),
                  itemCount: scenarios.length,
                  buildDefaultDragHandles: false,
                  onReorder: _store.reorder,
                  itemBuilder: (context, index) {
                    final scenario = scenarios[index];
                    return Padding(
                      key: ValueKey(scenario.id),
                      padding: const EdgeInsets.only(
                          bottom: AppSpacing.betweenCards),
                      child: _ScenarioCard(
                        scenario: scenario,
                        index: index,
                        onRun: () => _runScenario(context, scenario),
                        onEdit: () => _editScenario(context, scenario),
                        onDelete: () => _deleteScenario(context, scenario),
                        onShowInHomeChanged: (v) =>
                            _setShowInHome(scenario, v),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: null,
            onPressed: () => _createScenario(context),
            icon: const Icon(Icons.add),
            label: const Text('New scenario', style: AppTheme.fabLabelStyle),
          ),
        );
      },
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.scenario,
    required this.index,
    required this.onRun,
    required this.onEdit,
    required this.onDelete,
    required this.onShowInHomeChanged,
  });

  final Scenario scenario;
  final int index;
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
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.drag_indicator,
                          color: onSurface.withOpacity(0.6), size: 22),
                    ),
                  ),
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
