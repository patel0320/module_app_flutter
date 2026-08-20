class TemperatureAlert {
  final String id;
  final String moduleId;
  final double minC;
  final double maxC;
  final bool enabled;
  final DateTime? lastTriggeredAt;

  const TemperatureAlert({
    required this.id,
    required this.moduleId,
    required this.minC,
    required this.maxC,
    this.enabled = true,
    this.lastTriggeredAt,
  });

  bool isTriggered(double value) {
    if (minC > maxC || !enabled) return false;
    return value < minC || value > maxC;
  }
}
