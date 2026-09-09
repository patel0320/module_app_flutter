import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _Section(label: 'Account', children: [
              ListTile(leading: Icon(Icons.person), title: Text('Sign in')),
              ListTile(
                  leading: Icon(Icons.person_add),
                  title: Text('Create account')),
              ListTile(
                  leading: Icon(Icons.lock_reset),
                  title: Text('Reset password')),
            ]),
            const _Section(label: 'Backup & Sync', children: [
              ListTile(
                  leading: Icon(Icons.cloud_upload),
                  title: Text('Back up now')),
              ListTile(
                  leading: Icon(Icons.cloud_download), title: Text('Restore')),
            ]),
            _Section(label: 'Notifications', children: [
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('Offline & temperature alerts'),
                trailing: Switch(value: true, onChanged: (_) {}),
              ),
            ]),
            const _Section(label: 'Language', children: [
              ListTile(
                leading: Icon(Icons.language),
                title: Text('English'),
                trailing: Icon(Icons.check, color: AppColors.controlOn),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const _Section({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(label, style: Theme.of(context).textTheme.titleLarge),
        ),
        Card(
          color: AppColors.surface,
          margin: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}
