enum PhysicalInputMode { momentary, toggle, associated }

class PhysicalInput {
  final String id;
  final String moduleId;
  final int index;
  final PhysicalInputMode mode;
  final String? bindKey; // "channel:<id>" or "scenario:<id>".

  const PhysicalInput({
    required this.id,
    required this.moduleId,
    required this.index,
    this.mode = PhysicalInputMode.momentary,
    this.bindKey,
  });
}
