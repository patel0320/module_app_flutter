import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/scenario.dart';

class HomeQuickActionCard extends StatelessWidget {
  final Scenario scenario;
  const HomeQuickActionCard({super.key, required this.scenario});

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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              const Icon(Icons.play_arrow_rounded,
                  color: AppColors.controlOn, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  scenario.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.drag_handle, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
