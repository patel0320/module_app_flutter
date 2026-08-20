// lib/screens/rooms_screen.dart
//
// Brief section 2.5 "Organization by Rooms (Zones)": create, rename,
// reorder and delete the rooms/zones used to group scenarios and modules.
import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final List<Room> _rooms = mockRooms();

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final room = _rooms.removeAt(oldIndex);
      _rooms.insert(newIndex, room);
    });
  }

  Future<void> _addRoom() async {
    final String? name = await showTextInputDialog(context, title: 'New room', hint: 'e.g. Guest Cabin');
    if (name != null) {
      setState(() => _rooms.add(Room(id: 'room-${DateTime.now().millisecondsSinceEpoch}', name: name)));
    }
  }

  Future<void> _renameRoom(Room room) async {
    final String? name = await showTextInputDialog(context, title: 'Rename room', initialValue: room.name);
    if (name != null) setState(() => room.name = name);
  }

  Future<void> _deleteRoom(Room room) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete room',
      message: 'Delete "${room.name}"? Scenarios assigned to it will show as "No room".',
      confirmLabel: 'Delete',
    );
    if (confirmed) setState(() => _rooms.remove(room));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rooms')),
      body: _rooms.isEmpty
          ? const EmptyState(icon: Icons.meeting_room_outlined, message: 'No rooms yet.')
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(AppSpacing.outerPadding),
              itemCount: _rooms.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final room = _rooms[index];
                return Padding(
                  key: ValueKey(room.id),
                  padding: const EdgeInsets.only(bottom: AppSpacing.betweenCards),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.meeting_room_outlined),
                      title: Text(room.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Hold & drag to reorder'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _renameRoom(room)),
                          IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteRoom(room)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _addRoom,
        icon: const Icon(Icons.add),
        label: const Text('Add room'),
      ),
    );
  }
}
