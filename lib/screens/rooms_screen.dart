// lib/screens/rooms_screen.dart
//
// Brief section 2.5 "Organization by Rooms (Zones)": create, rename,
// reorder and delete the rooms/zones used to group scenarios and modules.
import 'package:flutter/material.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';

import '../models/models.dart';
import '../services/room_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});

  static final RoomStore _store = RoomStore.shared;

  Future<void> _addRoom(BuildContext context) async {
    final String? name = await showTextInputDialog(context,
        title: AppLocalizations.of(context).roomsNew,
        hint: AppLocalizations.of(context).roomsNewHint);
    if (name != null) _store.add(name);
  }

  Future<void> _renameRoom(BuildContext context, Room room) async {
    final String? name = await showTextInputDialog(context,
        title: AppLocalizations.of(context).roomsRename,
        initialValue: room.name);
    if (name != null) _store.rename(room, name);
  }

  Future<void> _deleteRoom(BuildContext context, Room room) async {
    final confirmed = await showConfirmDialog(
      context,
      title: AppLocalizations.of(context).roomsDelete,
      message: AppLocalizations.of(context).roomsDeleteMsg(room.name),
      confirmLabel: AppLocalizations.of(context).delete,
    );
    if (confirmed) _store.remove(room);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final rooms = _store.rooms;
        final l10n = AppLocalizations.of(context);
        return Scaffold(
          appBar: AppBar(title: Text(l10n.roomsTitle)),
          body: SafeArea(
            top: false,
            child: rooms.isEmpty
                ? Center(
                    child: EmptyState(
                      icon: Icons.meeting_room_outlined,
                      message: l10n.roomsEmpty,
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.outerPadding),
                    itemCount: rooms.length,
                    buildDefaultDragHandles: false,
                    onReorderItem: _store.reorder,
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
                                      .withValues(alpha: 0.6),
                                  size: 22,
                                ),
                              ),
                            ),
                            title: Text(room.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            subtitle: Text(l10n.homeHoldDragReorder),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _renameRoom(context, room),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _deleteRoom(context, room),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: null,
            onPressed: () => _addRoom(context),
            icon: const Icon(Icons.add),
            label: Text(l10n.roomsAdd, style: AppTheme.fabLabelStyle),
          ),
        );
      },
    );
  }
}
