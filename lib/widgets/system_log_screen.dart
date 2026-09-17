// lib/widgets/system_log_screen.dart
//
// Full-screen system log viewer for a device module: fetches the "system"
// page's `system_logs` section through `get_page_configuration`, renders the
// entries as a RecyclerView-style paged list with explicit Previous/Next
// pagination, and offers from/to time + tag filters.
import 'package:flutter/material.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';

import '../models/models.dart';
import '../services/module_status/module_status_service.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';

/// The active log filters, as configured in the filter dialog.
class _SystemLogFilter {
  const _SystemLogFilter({this.from, this.to, this.tag});

  final DateTime? from;
  final DateTime? to;
  final String? tag;

  bool get isActive => from != null || to != null || tag != null;
}

/// Opens the full-screen system log page for [module].
Future<void> showSystemLogScreen(BuildContext context, DeviceModule module) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => SystemLogScreen(module: module)),
  );
}

class SystemLogScreen extends StatefulWidget {
  const SystemLogScreen({super.key, required this.module});

  final DeviceModule module;

  @override
  State<SystemLogScreen> createState() => _SystemLogScreenState();
}

class _SystemLogScreenState extends State<SystemLogScreen> {
  static const int _pageSize = 10;

  final ScrollController _scrollController = ScrollController();
  final List<SystemLogEntry> _entries = [];
  List<SystemLogColumn> _columns = const [];

  /// Distinct output tags seen so far, offered in the tag filter dropdown.
  final Set<String> _knownTags = {};

  /// Last successfully loaded page number (0 = nothing loaded yet).
  int _page = 0;
  int _totalPages = 1;
  int _totalCount = 0;
  bool _loading = false;
  bool _initialLoadFailed = false;

  _SystemLogFilter _filter = const _SystemLogFilter();

  bool get _canGoPrevious => _page > 1 && !_loading;
  bool get _canGoNext => _page < _totalPages && !_loading;

  @override
  void initState() {
    super.initState();
    _loadPage(1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPage(int page) async {
    if (_loading || page < 1) return;
    if (_totalPages > 1 && page > _totalPages) return;
    setState(() => _loading = true);
    final pageEntity = await ModuleStatusService.shared.fetchSystemLogPage(
      widget.module.id,
      page: page,
      pageSize: _pageSize,
      from: _filter.from,
      to: _filter.to,
      tag: _filter.tag,
    );
    if (!mounted) return;
    final failed = pageEntity == null;
    setState(() {
      _loading = false;
      if (!failed) {
        _page = pageEntity.page;
        _totalPages = pageEntity.totalPages;
        _totalCount = pageEntity.totalCount;
        if (_columns.isEmpty) _columns = pageEntity.columns;
        _entries
          ..clear()
          ..addAll(pageEntity.rows);
        for (final entry in pageEntity.rows) {
          if (entry.tag.isNotEmpty) _knownTags.add(entry.tag);
        }
        _initialLoadFailed = false;
      } else if (_entries.isEmpty) {
        _initialLoadFailed = true;
      }
    });
    if (failed && _entries.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).systemLogLoadMoreFailed),
        ));
    }
    if (mounted && _page == page) {
      _scrollController.jumpTo(0);
    }
  }

  void _goToPage(int page) => _loadPage(page);

  void _reload() {
    setState(() {
      _page = 0;
      _entries.clear();
      _initialLoadFailed = false;
    });
    _loadPage(1);
  }

  Future<void> _openFilter() async {
    final result = await showDialog<_SystemLogFilter>(
      context: context,
      builder: (_) => _SystemLogFilterDialog(
        initial: _filter,
        tags: _knownTags.toList()..sort(),
      ),
    );
    if (result == null) return;
    setState(() => _filter = result);
    _reload();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.systemLogTitle),
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: _filter.isActive
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: l10n.systemLogFilterTooltip,
            onPressed: _openFilter,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_columns.isNotEmpty)
              _ColumnHeaderRow(columns: _columns, onSurface: onSurface),
            const Divider(height: 1),
            Expanded(child: _buildBody(l10n, onSurface)),
            if (_totalCount > 0) _buildPagination(l10n, onSurface),
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
            FilledButton(onPressed: _reload, child: Text(l10n.retry)),
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

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
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

  /// Bottom pagination bar: Previous/Next buttons, current page and total rows.
  Widget _buildPagination(AppLocalizations l10n, Color onSurface) {
    return Container(
      decoration: BoxDecoration(
        border:
            Border(top: BorderSide(color: onSurface.withValues(alpha: 0.1))),
      ),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.outerPadding),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: l10n.systemLogPrevious,
              onPressed: _canGoPrevious ? () => _goToPage(_page - 1) : null,
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.systemLogPage(_page, _totalPages),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _loading
                            ? onSurface.withValues(alpha: 0.4)
                            : onSurface),
                  ),
                  Text(
                    l10n.systemLogEntries(_totalCount),
                    style: TextStyle(
                        fontSize: 12, color: onSurface.withValues(alpha: 0.55)),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: l10n.systemLogNext,
              onPressed: _canGoNext ? () => _goToPage(_page + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog collecting the log filters: from/to timestamps and an output tag.
class _SystemLogFilterDialog extends StatefulWidget {
  const _SystemLogFilterDialog({required this.initial, required this.tags});

  final _SystemLogFilter initial;
  final List<String> tags;

  @override
  State<_SystemLogFilterDialog> createState() => _SystemLogFilterDialogState();
}

class _SystemLogFilterDialogState extends State<_SystemLogFilterDialog> {
  late DateTime? _from;
  late DateTime? _to;
  late String? _tag;

  @override
  void initState() {
    super.initState();
    _from = widget.initial.from;
    _to = widget.initial.to;
    _tag = widget.initial.tag;
  }

  Future<void> _pickTimestamp({
    required DateTime? current,
    required bool isFrom,
  }) async {
    final now = DateTime.now();
    final initial = current ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    setState(() {
      final picked =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  String _format(DateTime? value) {
    if (value == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return AlertDialog(
      title: Text(l10n.systemLogFilterTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FilterField(
              label: l10n.systemLogFilterFrom,
              value: _format(_from),
              onTap: () => _pickTimestamp(current: _from, isFrom: true),
              onClear:
                  _from == null ? null : () => setState(() => _from = null),
            ),
            const SizedBox(height: 12),
            _FilterField(
              label: l10n.systemLogFilterTo,
              value: _format(_to),
              onTap: () => _pickTimestamp(current: _to, isFrom: false),
              onClear: _to == null ? null : () => setState(() => _to = null),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _tag,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.systemLogFilterTag,
                prefixIcon: const Icon(Icons.sell_outlined),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(l10n.systemLogFilterAllTags),
                ),
                for (final tag in widget.tags)
                  DropdownMenuItem<String?>(
                    value: tag,
                    child: Text(tag, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => setState(() => _tag = value),
            ),
            if (widget.tags.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.systemLogFilterNoTags,
                  style: TextStyle(
                      fontSize: 12, color: onSurface.withValues(alpha: 0.55)),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            const _SystemLogFilter(),
          ),
          child: Text(l10n.systemLogFilterReset),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _SystemLogFilter(from: _from, to: _to, tag: _tag),
          ),
          child: Text(l10n.systemLogFilterApply),
        ),
      ],
    );
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.schedule),
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: AppLocalizations.of(context).systemLogFilterClear,
                  onPressed: onClear,
                ),
        ),
        child: Text(
          value.isEmpty ? '—' : value,
          style: value.isEmpty
              ? TextStyle(color: onSurface.withValues(alpha: 0.4))
              : null,
        ),
      ),
    );
  }
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
