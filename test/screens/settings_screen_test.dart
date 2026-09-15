// Renders the real Settings screen to verify the new Command protocol section
// (TCP 5008 vs HTTP/HTTPS) builds and localizes correctly.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';
import 'package:soleux_device_manager/screens/settings_screen.dart';
import 'package:soleux_device_manager/services/settings_store.dart';

void main() {
  testWidgets('Settings screen renders the command protocol picker',
      (tester) async {
    // Tall viewport so the whole Settings ListView (incl. the below-the-fold
    // Command protocol section) is built.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Command protocol'), findsOneWidget);
    expect(find.text('TCP (port 5008)'), findsOneWidget);
    expect(find.text('HTTP'), findsOneWidget);
    expect(find.text('HTTPS'), findsOneWidget);
  });

  testWidgets('selecting HTTPS persists the transport choice', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsScreen(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('HTTPS'));
    await tester.pumpAndSettle();
    expect(SettingsStore.shared.commandTransport, CommandTransportMode.https);
  });
}
