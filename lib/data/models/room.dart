class Room {
  final String id;
  final String locationId;
  final String name;
  final int order;

  const Room({
    required this.id,
    required this.locationId,
    required this.name,
    this.order = 0,
  });
}
