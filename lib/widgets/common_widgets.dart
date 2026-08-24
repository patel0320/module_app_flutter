// lib/widgets/common_widgets.dart
//
// Small reusable UI building blocks shared by several screens, kept in one
// file to avoid duplicating the same layout code across the prototype.
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// Small green/red dot used everywhere a module's connectivity status is
/// shown (brief section 2.1: "a green dot for Online or a red dot for
/// Offline").
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.status, this.size = 10});

  final ConnectionStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool online = status == ConnectionStatus.online;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: online ? AppColors.online : AppColors.offlineAlert,
        boxShadow: [
          BoxShadow(
            color: (online ? AppColors.online : AppColors.offlineAlert).withOpacity(0.4),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}

/// A full width, high-visibility banner used for the offline-module alert
/// and the temperature-threshold alert (brief section I, points 2 and 3
/// call for the *same* prominent red banner treatment for both).
class AlertBanner extends StatelessWidget {
  const AlertBanner({
    super.key,
    required this.message,
    required this.onTap,
    this.icon = Icons.warning_amber_rounded,
  });

  final String message;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.offlineAlert,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

/// A left-aligned section title with optional trailing action, used to
/// break every screen into clearly labelled groups.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.padding});

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Circular icon avatar used for channel/scenario icons, with a subtle
/// outlined high-contrast style consistent across the app.
class IconAvatar extends StatelessWidget {
  const IconAvatar({super.key, required this.icon, this.size = 44, this.filled = false});

  final IconData icon;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final Color fg = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? fg : Colors.transparent,
        border: Border.all(color: fg.withOpacity(filled ? 0 : 0.25)),
      ),
      child: Icon(icon, color: filled ? Theme.of(context).colorScheme.surface : fg, size: size * 0.5),
    );
  }
}

/// Placeholder shown when a list has no items yet.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final Color fg = Theme.of(context).colorScheme.onSurface.withOpacity(0.4);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 40, color: fg),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: fg), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// A round chip-like tag used to show a room name on scenario/module cards.
class RoomTag extends StatelessWidget {
  const RoomTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final Color fg = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg.withOpacity(0.75))),
    );
  }
}

/// Confirmation dialog helper (used for destructive actions like removing a
/// module or deleting a room).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = true,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).cancel)),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.offlineAlert, foregroundColor: Colors.white)
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Simple text-input dialog helper (used for renaming modules/rooms).
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String initialValue = '',
  String hint = '',
  String confirmLabel = 'Save',
}) async {
  final controller = TextEditingController(text: initialValue);
  final String? result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return (result == null || result.isEmpty) ? null : result;
}

/// Dialog editing a module's identity (name, IP address, TCP port) in place.
/// Returns true when the user saved; the passed [module] is updated directly.
Future<bool> showEditModuleInfoDialog(BuildContext context, DeviceModule module) async {
  final nameController = TextEditingController(text: module.name);
  final ipController = TextEditingController(text: module.ipAddress);
  final portController = TextEditingController(text: module.tcpPort.toString());

  final bool? saved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(AppLocalizations.of(context).moduleInfoTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            autofocus: true,
            decoration: InputDecoration(
                labelText: AppLocalizations.of(context).moduleName,
                prefixIcon: const Icon(Icons.edit_outlined)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ipController,
            decoration: InputDecoration(
                labelText: AppLocalizations.of(context).ipAddress,
                prefixIcon: const Icon(Icons.lan_outlined)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: portController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                labelText: AppLocalizations.of(context).tcpPort,
                prefixIcon: const Icon(Icons.router_outlined)),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(AppLocalizations.of(context).save),
        ),
      ],
    ),
  );

  final String name = nameController.text.trim();
  final String ip = ipController.text.trim();
  final int? port = int.tryParse(portController.text.trim());
  nameController.dispose();
  ipController.dispose();
  portController.dispose();

  if (saved == true) {
    if (name.isNotEmpty) module.name = name;
    if (ip.isNotEmpty) module.ipAddress = ip;
    if (port != null) module.tcpPort = port;
  }
  return saved == true;
}

/// Compact status header (online/offline + IP/room + internal temperature)
/// reused at the top of every module detail / control screen.
class ModuleStatusHeader extends StatelessWidget {
  const ModuleStatusHeader({super.key, required this.module});

  final DeviceModule module;

  @override
  Widget build(BuildContext context) {
    final Color onSurface = Theme.of(context).colorScheme.onSurface;
    final bool online = module.status == ConnectionStatus.online;
    final bool tempAlert = module.isOverTemperature;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            StatusDot(status: module.status, size: 14),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    online ? AppLocalizations.of(context).online : AppLocalizations.of(context).offline,
                    style: TextStyle(fontWeight: FontWeight.w800, color: online ? AppColors.online : AppColors.offlineAlert),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${module.ipAddress} · ${module.roomName}',
                    style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.55)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(Icons.thermostat, size: 20, color: tempAlert ? AppColors.offlineAlert : onSurface.withOpacity(0.6)),
                Text(
                  '${module.internalTempC.toStringAsFixed(1)}°C',
                  style: TextStyle(fontWeight: FontWeight.w700, color: tempAlert ? AppColors.offlineAlert : onSurface),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A single dimmer channel: name/icon, brightness readout, quick 0%/100%
/// shortcuts and a slider - shared by the DC and AC dimmer screens (brief
/// section 2.3).
class DimmerChannelCard extends StatelessWidget {
  const DimmerChannelCard({
    super.key,
    required this.channel,
    required this.onChanged,
    required this.onEdit,
    this.onChangeEnd,
  });

  final ChannelOutput channel;
  final ValueChanged<int> onChanged;
  final VoidCallback onEdit;

  /// Invoked once when a drag gesture ends, carrying the settled brightness.
  final ValueChanged<int>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final bool isOn = channel.brightness > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconAvatar(icon: channel.icon, filled: isOn),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(channel.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                Text('${channel.brightness}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
              ],
            ),
            Row(
              children: [
                IconButton(
                  tooltip: AppLocalizations.of(context).cwTurnOff,
                  icon: const Icon(Icons.brightness_low),
                  onPressed: () {
                    onChanged(0);
                    onChangeEnd?.call(0);
                  },
                ),
                Expanded(
                  child: Slider(
                    value: channel.brightness.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: '${channel.brightness}%',
                    onChanged: (v) => onChanged(v.round()),
                    onChangeEnd: (v) => onChangeEnd?.call(v.round()),
                  ),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context).cwFullBrightness,
                  icon: const Icon(Icons.brightness_high),
                  onPressed: () {
                    onChanged(100);
                    onChangeEnd?.call(100);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Formats a [DateTime] as a short relative-ish timestamp for log lists.
String formatLogTimestamp(DateTime time, AppLocalizations l10n) {
  final Duration diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return l10n.cwJustNow;
  if (diff.inMinutes < 60) return l10n.cwMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.cwHoursAgo(diff.inHours);
  if (diff.inDays < 30) return l10n.cwDaysAgo(diff.inDays);
  return '${time.day}/${time.month}/${time.year}';
}
