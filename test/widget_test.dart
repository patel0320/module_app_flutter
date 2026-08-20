import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:module_app_flutter/app.dart';

void main() {
  testWidgets('App boots to Home with bottom navigation', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ModuleApp()));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Configuration'), findsOneWidget);
    expect(find.text('Scenarios'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Quick access'), findsOneWidget);
  });
}
