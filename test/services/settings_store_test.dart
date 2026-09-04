// Tests for the app-level command-protocol preference
// (doc/Soleux_Control_API_Command_Specification_v0.2.md §"Transport mapping"):
// it defaults to the TCP session and persists the HTTP/HTTPS selection.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soleux_device_manager/services/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('command transport defaults to TCP (port 5008)', () async {
    final store = SettingsStore.forTesting();
    await store.init();
    expect(store.commandTransport, CommandTransportMode.tcp);
  });

  test('command transport selection persists across reloads', () async {
    final store = SettingsStore.forTesting();
    await store.init();

    await store.setCommandTransport(CommandTransportMode.http);
    expect(store.commandTransport, CommandTransportMode.http);

    final reloaded = SettingsStore.forTesting();
    await reloaded.init();
    expect(reloaded.commandTransport, CommandTransportMode.http);
  });

  test('mode labels and descriptions are stable', () {
    expect(CommandTransportMode.tcp.label, 'tcp');
    expect(CommandTransportMode.http.description, 'HTTP port 80');
    expect(CommandTransportMode.https.description, 'HTTPS port 443');
  });
}