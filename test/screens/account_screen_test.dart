// Widget tests for the Account screen's local backup/restore flow.
//
// File IO (the backup JSON read) is real async work, so interactions that
// touch the disk are given time inside `tester.runAsync`; everything else runs
// under the fake-async test clock. The write path is covered by
// test/services/backup_service_test.dart.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';
import 'package:soleux_device_manager/screens/account_screen.dart';
import 'package:soleux_device_manager/services/backup_service.dart';

/// Pure-Dart stand-in for the path_provider platform channel, so tests never
/// touch a real plugin.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.docPath);

  final String docPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docPath;
}

/// v1 backup fixture written straight to disk by [BackupDocument]'s schema.
Map<String, dynamic> _fixtureJson() => {
      'schema': {'major': 1, 'minor': 0},
      'exportedAt': '2026-09-15T00:00:00.000',
      'settings': {'themeMode': 'dark', 'locale': 'ro'},
      'location': {'id': 'loc-1', 'name': 'Casa'},
      'rooms': [
        {'id': 'r1', 'name': 'Living room'}
      ],
      'scenarios': <Object?>[],
      'modules': <Object?>[],
      'automations': <Object?>[],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  String backupPath(Directory d) =>
      '${d.path}${Platform.pathSeparator}${BackupService.fileName}';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('account_screen_test');
    PathProviderPlatform.instance = _FakePathProvider(dir.path);
  });

  tearDown(() async {
    // Windows can briefly hold the file open after a test; retry cleanup.
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        await dir.delete(recursive: true);
        break;
      } on PathAccessException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  });

  Future<void> pumpAccount(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AccountScreen(),
    ));
    await tester.pumpAndSettle();
  }

  /// Alternates fake-clock pumps with real-async windows so multi-hop file IO
  /// chains (e.g. readBackup: exists -> readAsString -> parse) can complete.
  Future<void> pumpRealAsync(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)));
    }
  }

  /// Taps [finder] and lets any real-async work (file IO) make progress.
  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pump();
    await pumpRealAsync(tester);
    await tester.pumpAndSettle();
  }

  testWidgets('Restore with no local backup shows the no-backup notice',
      (tester) async {
    await pumpAccount(tester);
    await tapAndSettle(tester, find.widgetWithText(OutlinedButton, 'Restore'));

    expect(find.text('No local backup was found.'), findsOneWidget);
  });

  testWidgets(
      'Restore offers fresh-load and migrate options and applies the '
      'backup', (tester) async {
    // Seed a local backup file (real IO happens in the runAsync block).
    await tester.runAsync(() async {
      File(backupPath(dir)).writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(_fixtureJson()));
    });
    await pumpAccount(tester);
    await tapAndSettle(tester, find.widgetWithText(OutlinedButton, 'Restore'));

    // Step 1: the mode dialog appears with both options.
    expect(find.text('Fresh load'), findsOneWidget);
    expect(find.text('Migrate'), findsOneWidget);
    // The version line also carries the export timestamp, so match on a slice.
    expect(find.textContaining('Backup version 1.0'), findsOneWidget);

    // Step 2: choose migrate and confirm.
    await tester.tap(find.text('Migrate'));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Restore'));

    expect(find.text('Configuration restored from backup.'), findsOneWidget);
  });
}
