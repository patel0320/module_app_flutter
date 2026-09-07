import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/channel.dart';
import '../../data/models/scenario.dart';

class HomeQuickActionCard extends StatelessWidget {
  final Scenario scenario;
  final String roomName;
  const HomeQuickActionCard(
      {super.key, required this.scenario, required this.roomName});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: scenario.type == ScenarioType.slider
            ? () => Navigator.of(context)
                .pushNamed('/scenario-slider', arguments: scenario)
            : () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.play_arrow_rounded,
                      color: AppColors.controlOn, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      scenario.name,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.drag_handle, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.meeting_room_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    roomName,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
              if (scenario.actions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final action in scenario.actions)
                      _ActionChip(action: action),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final ScenarioAction action;
  const _ActionChip({required this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_meta.$1, size: 14, color: AppColors.controlOn),
          const SizedBox(width: 4),
          Text(
            _meta.$2,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  (IconData, String) get _meta {
    switch (action.type) {
      case ScenarioActionType.setRelay:
        return (action.targetState == true ? Icons.power : Icons.power_off,
            action.targetState == true ? 'ON' : 'OFF');
      case ScenarioActionType.setBrightness:
        return (Icons.brightness_6, '${action.brightnessPct ?? 0}%');
      case ScenarioActionType.blindMove:
        return (Icons.blinds, switch (action.blindDir) {
          BlindDirection.up => 'UP',
          BlindDirection.down => 'DOWN',
          _ => 'STOP',
        });
    }
  }
}