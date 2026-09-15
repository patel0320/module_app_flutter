// lib/screens/account_screen.dart
//
// Brief section 3.1 "Account Management and Cloud Synchronization":
// profile details, password change, and backup/restore - the
// mechanism that lets a user move to a new phone without reconfiguring.
// Backup writes a versioned JSON snapshot of the whole configuration
// (settings, location, rooms, scenarios, modules, automations) to local
// storage; restore reads it back, offering a fresh load or a version
// migration (see BackupService).
import 'package:flutter/material.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';

import '../services/backup_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _nameController = TextEditingController(text: 'Alex Popescu');
  final _emailController =
      TextEditingController(text: 'alex.popescu@example.com');
  DateTime _lastBackup = DateTime.now().subtract(const Duration(hours: 6));
  bool _backingUp = false;
  bool _restoring = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).accountChangePassword),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration: InputDecoration(
                  labelText:
                      AppLocalizations.of(context).accountCurrentPassword),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).accountNewPassword),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                Navigator.pop(context, false);
              },
              child: Text(AppLocalizations.of(context).cancel)),
          FilledButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                Navigator.pop(context, true);
              },
              child: Text(AppLocalizations.of(context).update)),
        ],
      ),
    );
    currentController.dispose();
    newController.dispose();
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).accountPasswordUpdated)));
    }
  }

  Future<void> _backupNow() async {
    setState(() => _backingUp = true);
    final l10n = AppLocalizations.of(context);
    // The write completes almost instantly, so keep the spinner visible for a
    // moment to make the completed state obvious.
    final stopwatch = Stopwatch()..start();
    try {
      await BackupService.shared.backup();
      final remaining = 900 - stopwatch.elapsedMilliseconds;
      if (remaining > 0) {
        await Future<void>.delayed(Duration(milliseconds: remaining));
      }
      if (!mounted) return;
      setState(() {
        _backingUp = false;
        _lastBackup = DateTime.now();
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.accountBackupCompleted)));
    } on Exception {
      if (!mounted) return;
      setState(() => _backingUp = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.backupExportFailed)));
    }
  }

  Future<void> _restoreBackup() async {
    final l10n = AppLocalizations.of(context);

    BackupDocument? backup;
    try {
      backup = await BackupService.shared.readBackup();
    } on Exception {
      backup = null;
    }
    if (!mounted) return;
    if (backup == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.backupNoBackupFound)));
      return;
    }
    final BackupDocument doc = backup;

    // A backup from a structurally newer build cannot be downgraded.
    if (doc.schema.compareTo(BackupService.currentVersion) > 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.backupNewerVersion)));
      return;
    }

    final needsMigration =
        doc.schema.major < BackupService.currentVersion.major;

    final mode = await showDialog<BackupRestoreMode>(
      context: context,
      builder: (ctx) {
        var selected = needsMigration
            ? BackupRestoreMode.migrate
            : BackupRestoreMode.freshLoad;
        final created = doc.exportedAt == null
            ? ''
            : l10n
                .backupCreatedLabel(formatLogTimestamp(doc.exportedAt!, l10n));
        final versionLine = l10n.backupVersionLabel(doc.schema.toString());
        final onSurface = Theme.of(ctx).colorScheme.onSurface;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text(l10n.accountRestoreDialog),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$versionLine\n$created',
                    style: TextStyle(
                      fontSize: 12,
                      color: onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.accountRestoreMsg),
                  const SizedBox(height: 12),
                  RadioGroup<BackupRestoreMode>(
                    groupValue: selected,
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selected = v);
                    },
                    child: Column(
                      children: [
                        RadioListTile<BackupRestoreMode>(
                          value: BackupRestoreMode.freshLoad,
                          title: Text(l10n.backupFreshLoad),
                          subtitle: Text(l10n.backupFreshLoadDesc),
                          secondary: const Icon(Icons.restore_page_outlined),
                        ),
                        const Divider(height: 1),
                        RadioListTile<BackupRestoreMode>(
                          value: BackupRestoreMode.migrate,
                          title: Text(l10n.backupMigrate),
                          subtitle: Text(l10n.backupMigrateDesc),
                          secondary: const Icon(Icons.auto_fix_high_outlined),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, selected),
                child: Text(l10n.restore),
              ),
            ],
          ),
        );
      },
    );
    if (mode == null || !mounted) return;

    setState(() => _restoring = true);
    try {
      await BackupService.shared.restore(doc, mode: mode);
      if (!mounted) return;
      setState(() => _restoring = false);
      final migrated = mode == BackupRestoreMode.migrate && needsMigration;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(migrated
              ? l10n.backupMigratedRestored
              : l10n.accountConfigRestored)));
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _restoring = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.backupRestoreFailed}\n$e')));
    }
  }

  void _saveProfile() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).accountProfileUpdated)));
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.outerPadding),
          children: [
            SectionHeader(l10n.accountProfileSection),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                  labelText: l10n.accountFullName,
                  prefixIcon: const Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              readOnly: true,
              decoration: InputDecoration(
                  labelText: l10n.accountEmail,
                  prefixIcon: const Icon(Icons.mail_outline)),
            ),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: _saveProfile, child: Text(l10n.accountSaveChanges)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _changePassword,
              icon: const Icon(Icons.lock_reset_outlined),
              label: Text(l10n.accountChangePassword),
            ),
            const SizedBox(height: 24),
            SectionHeader(l10n.accountCloudSection),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cloud_done_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(l10n.accountLastBackup(
                                formatLogTimestamp(_lastBackup, l10n)))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.accountBackupDesc,
                      style: TextStyle(
                          fontSize: 12,
                          color: onSurface.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                              onPressed: _restoring ? null : _restoreBackup,
                              child: _restoring
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    )
                                  : Text(l10n.restore)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _backingUp ? null : _backupNow,
                            child: _backingUp
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                    ),
                                  )
                                : Text(l10n.accountBackUpNow),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
