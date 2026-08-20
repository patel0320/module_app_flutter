// lib/screens/account_screen.dart
//
// Brief section 3.1 "Account Management and Cloud Synchronization":
// profile details, password change, and cloud backup/restore - the
// mechanism that lets a user move to a new phone without reconfiguring.
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _nameController = TextEditingController(text: 'Alex Popescu');
  final _emailController = TextEditingController(text: 'alex.popescu@example.com');
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
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Update')),
        ],
      ),
    );
    currentController.dispose();
    newController.dispose();
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated.')));
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup completed.')));
  }

  Future<void> _restoreBackup() async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Restore backup',
      message: 'This will overwrite the current configuration on this device with your last cloud backup.',
      confirmLabel: 'Restore',
      destructive: false,
    );
    if (confirmed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuration restored from backup.')));
    }
  }

  void _saveProfile() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.outerPadding),
        children: [
          const SectionHeader('Profile'),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            readOnly: true,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saveProfile, child: const Text('Save changes')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _changePassword,
            icon: const Icon(Icons.lock_reset_outlined),
            label: const Text('Change password'),
          ),
          const SizedBox(height: 24),
          const SectionHeader('Cloud Backup & Sync'),
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
                      Expanded(child: Text('Last backup: ${formatLogTimestamp(_lastBackup)}')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your modules, scenarios, rooms and settings are backed up to the '
                    'cloud so you can switch to a new phone without any reconfiguration.',
                    style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.6)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(onPressed: _restoreBackup, child: const Text('Restore')),
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
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                )
                              : const Text('Back Up Now'),
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
