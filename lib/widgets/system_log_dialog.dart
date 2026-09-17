// lib/widgets/system_log_dialog.dart
//
// Full-screen system log viewer for a device module: fetches the "system"
// page's `system_logs` section through `get_page_configuration`,
// renders the entries as a RecyclerView-style paged list and transparently
// loads the next page when the user scrolls to the bottom.
import 'package:flutter/material.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';

import '../models/models.dart';
import '../services/module_status/module_status_service.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';

/// Opens the full-screen system log dialog for [module].
Future<void> showSystemLogDialog(BuildContext context, DeviceModule module) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => SystemLogDialog(module: module),
  );
}

class SystemLogDialog extends StatefulWidget {
  const SystemLogDialog({super.key, required this.module});

  final DeviceModule module;

  @override
  State<SystemLogDialog> createState() => _SystemLogDialogState();
}

class _SystemLogDialogState extends State<SystemLogDialog> {
  static const int _pageSize = 10;

  final ScrollController _scrollController = ScrollController();
  final List<SystemLogEntry> _entries = [];
  List<SystemLogColumn> _columns = const [];

  /// Last successfully loaded page number (0 = nothing loaded yet).
  int _page = 0;
  int _totalPages = 1;
  bool _loading = false;
  bool _initialLoadFailed = false;
  bool _loadMoreFailed = false;

  bool get _hasMore => _page < _totalPages;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNextPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Fetches the next page when the list is scrolled near its bottom.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _loadMoreFailed = false;
    });
    final nextPage = _page + 1;
    final page = await ModuleStatusService.shared.fetchSystemLogPage(
      widget.module.id,
      page: nextPage,
      pageSize: _pageSize,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (page == null) {
        if (_entries.isEmpty) _initialLoadFailed = true;
        _loadMoreFailed = _entries.isNotEmpty;
      } else {
        _page = page.page;
        _totalPages = page.totalPages;
        if (_columns.isEmpty) _columns = page.columns;
        _entries.addAll(page.rows);
      }
    });
  }

  void _retry() {
    if (_entries.isEmpty) {
      setState(() => _initialLoadFailed = false);
    }
    _loadNextPage();
  }

  String? _cellValue(SystemLogEntry entry, String columnKey) =>
      switch (columnKey) {
        'date_time' => entry.dateTime,
        'tag' => entry.tag,
        'state' => entry.state,
        'note' => entry.note,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Dialog.fullscreen(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(AppSpacing.outerPadding, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.systemLogTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.close,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            if (_columns.isNotEmpty)
              _ColumnHeaderRow(columns: _columns, onSurface: onSurface),
            const Divider(height: 1),
            Expanded(child: _buildBody(l10n, onSurface)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, Color onSurface) {
    if (_initialLoadFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 40, color: onSurface.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(l10n.systemLogLoadFailed,
                textAlign: TextAlign.center,
                style: TextStyle(color: onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 8),
            FilledButton(onPressed: _retry, child: Text(l10n.retry)),
          ],
        ),
      );
    }

    if (_entries.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_entries.isEmpty) {
      return Center(
        child: EmptyState(
            icon: Icons.receipt_long_outlined, message: l10n.systemLogEmpty),
      );
    }

    final itemCount = _entries.length + (_hasMore || _loading ? 1 : 0);
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= _entries.length) {
          return _buildFooter(l10n);
        }
        final entry = _entries[index];
        return _LogRow(
          entry: entry,
          columns: _columns,
          cellValue: (key) => _cellValue(entry, key) ?? '',
          onSurface: onSurface,
        );
      },
    );
  }

  Widget _buildFooter(AppLocalizations l10n) => SizedBox(
        height: 56,
        child: Center(
          child: _loadMoreFailed
              ? TextButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.systemLogLoadMoreFailed),
                )
              : const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
        ),
      );
}

/// The fixed header row listing every column the device returned.
class _ColumnHeaderRow extends StatelessWidget {
  const _ColumnHeaderRow({required this.columns, required this.onSurface});

  final List<SystemLogColumn> columns;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.outerPadding, vertical: 8),
      child: Row(
        children: [
          for (final column in columns)
            Expanded(
              child: Text(
                column.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A single system log entry row (one line per column key).
class _LogRow extends StatelessWidget {
  const _LogRow({
    required this.entry,
    required this.columns,
    required this.cellValue,
    required this.onSurface,
  });

  final SystemLogEntry entry;
  final List<SystemLogColumn> columns;
  final String Function(String key) cellValue;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOn = entry.state.toUpperCase() == 'ON';
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.outerPadding, vertical: 6),
      child: Row(
        children: [
          for (final column in columns)
            Expanded(
              child: _Cell(
                  label: cellValue(column.key),
                  columnKey: column.key,
                  scheme: scheme,
                  onSurface: onSurface,
                  isOn: isOn),
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.columnKey,
    required this.scheme,
    required this.onSurface,
    required this.isOn,
  });

  final String label;
  final String columnKey;
  final ColorScheme scheme;
  final Color onSurface;
  final bool isOn;

  @override
  Widget build(BuildContext context) {
    if (columnKey == 'state') {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isOn
                ? AppColors.online.withValues(alpha: 0.15)
                : onSurface.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
                color: isOn
                    ? AppColors.online.withValues(alpha: 0.5)
                    : onSurface.withValues(alpha: 0.2)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isOn ? AppColors.online : onSurface,
            ),
          ),
        ),
      );
    }
    return Text(
      label,
      overflow: TextOverflow.ellipsis,
      maxLines: 2,
      style: columnKey == 'date_time'
          ? TextStyle(fontSize: 12, color: onSurface.withValues(alpha: 0.7))
          : TextStyle(
              fontWeight:
                  columnKey == 'tag' ? FontWeight.w700 : FontWeight.w500,
              color: columnKey == 'note'
                  ? onSurface.withValues(alpha: 0.75)
                  : onSurface),
    );
  }
}
