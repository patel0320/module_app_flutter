import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class ModuleStatusDot extends StatelessWidget {
  final bool online;
  const ModuleStatusDot({super.key, required this.online});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: online ? AppColors.online : AppColors.offline,
      ),
    );
  }
}
