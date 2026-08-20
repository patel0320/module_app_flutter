import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/module.dart';

class TemperatureCard extends StatelessWidget {
  final Module module;
  final double temperature;
  const TemperatureCard({super.key, required this.module, required this.temperature});

  @override
  Widget build(BuildContext context) {
    final exceeded = temperature > 30.0 || temperature < 10.0;
    return Material(
      color: exceeded ? AppColors.offline : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        leading: Icon(Icons.thermostat, color: exceeded ? Colors.white : AppColors.warning),
        title: Text(module.name),
        subtitle: Text('${temperature.toStringAsFixed(1)} °C'),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}
