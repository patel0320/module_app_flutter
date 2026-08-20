enum EventLogType {
  moduleOffline,
  moduleOnline,
  outputOn,
  outputOff,
  scenarioRun,
  temperatureAlert,
  error,
}

class EventLogEntry {
  final String id;
  final EventLogType type;
  final String entityId;
  final Map<String, Object?> payload;
  final DateTime occurredAt;

  const EventLogEntry({
    required this.id,
    required this.type,
    required this.entityId,
    this.payload = const {},
    required this.occurredAt,
  });
}
