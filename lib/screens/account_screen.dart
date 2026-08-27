// lib/screens/account_screen.dart
//
// Brief section 3.1 "Account Management and Cloud Synchronization":
// profile details, password change, and cloud backup/restore - the
// mechanism that lets a user move to a new phone without reconfiguring.
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context).cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
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
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _backingUp = false;
      _lastBackup = DateTime.now();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).accountBackupCompleted)));
  }

  Future<void> _restoreBackup() async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: AppLocalizations.of(context).accountRestoreDialog,
      message: AppLocalizations.of(context).accountRestoreMsg,
      confirmLabel: AppLocalizations.of(context).restore,
      destructive: false,
    );
    if (confirmed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).accountConfigRestored)));
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
      body: ListView(
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
                        fontSize: 12, color: onSurface.withOpacity(0.6)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                            onPressed: _restoreBackup,
                            child: Text(l10n.restore)),
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
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
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
    );
  }
}
