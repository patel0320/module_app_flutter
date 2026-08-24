// lib/screens/rooms_screen.dart
//
// Brief section 2.5 "Organization by Rooms (Zones)": create, rename,
// reorder and delete the rooms/zones used to group scenarios and modules.
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/room_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});

  static final RoomStore _store = RoomStore.shared;

  Future<void> _addRoom(BuildContext context) async {
    final String? name = await showTextInputDialog(context, title: 'New room', hint: 'e.g. Guest Cabin');
    if (name != null) _store.add(name);
  }

  Future<void> _renameRoom(BuildContext context, Room room) async {
    final String? name = await showTextInputDialog(context, title: 'Rename room', initialValue: room.name);
    if (name != null) _store.rename(room, name);
  }

  Future<void> _deleteRoom(BuildContext context, Room room) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete room',
      message: 'Delete "${room.name}"? Scenarios assigned to it will show as "No room".',
      confirmLabel: 'Delete',
    );
    if (confirmed) _store.remove(room);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final rooms = _store.rooms;
        return Scaffold(
          appBar: AppBar(title: const Text('Rooms')),
              body: rooms.isEmpty
                  ? const Center(
                      child: EmptyState(
                        icon: Icons.meeting_room_outlined,
                        message: 'No rooms yet.',
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.outerPadding),
                      itemCount: rooms.length,
                      buildDefaultDragHandles: false,
                      onReorder: _store.reorder,
                      itemBuilder: (context, index) {
                        final room = rooms[index];
                        return Padding(
                          key: ValueKey(room.id),
                          padding: const EdgeInsets.only(
                              bottom: AppSpacing.betweenCards),
                          child: Card(
                            child: ListTile(
                              leading: ReorderableDragStartListener(
                                index: index,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(
                                    Icons.drag_indicator,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                    size: 22,
                                  ),
                                ),
                              ),
                              title: Text(room.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: const Text('Hold & drag to reorder'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () =>
                                        _renameRoom(context, room),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () =>
                                        _deleteRoom(context, room),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: null,
            onPressed: () => _addRoom(context),
            icon: const Icon(Icons.add),
            label: const Text('Add room', style: AppTheme.fabLabelStyle),
          ),
        );
      },
    );
  }
}
