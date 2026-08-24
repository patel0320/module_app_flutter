// lib/main.dart
//
// App entry point: Material 3 theme wiring and top-level navigation.
// This is a fully static UI prototype - there is no backend, network, or
// database call anywhere in this codebase. All data is hardcoded in
// lib/data/mock_data.dart and mutated only in local widget state.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'screens/account_screen.dart';
import 'screens/add_module_screen.dart';
import 'screens/automations_screen.dart';
import 'screens/configuration_screen.dart';
import 'screens/event_history_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/language_settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/notifications_settings_screen.dart';
import 'screens/register_screen.dart';
import 'screens/rooms_screen.dart';
import 'screens/scenarios_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/system_status_screen.dart';
import 'services/room_store.dart';
import 'services/scenario_store.dart';
import 'theme/app_theme.dart';
import 'theme/theme_palettes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Kick off loading the persisted room and scenario lists before the first
  // frame so the Rooms / Scenarios / Home screens reflect storage immediately.
  RoomStore.shared.init();
  ScenarioStore.shared.init();
  runApp(const AutomationApp());
}

/// Root widget: configures Material 3 light/dark theming and the named
/// route table for every screen that does not require constructor
/// arguments. Screens that need specific data (module detail pages,
/// editors, etc.) are pushed directly with `Navigator.push` from the
/// screen that triggers the navigation.
class AutomationApp extends StatelessWidget {
  const AutomationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return ValueListenableBuilder<HomeThemeId>(
          valueListenable: homeThemeIdNotifier,
          builder: (context, themeId, _) {
            return MaterialApp(
              title: 'Relay & Dimming Control',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightFor(themeId),
              darkTheme: AppTheme.darkFor(themeId),
              themeMode: mode,
              scrollBehavior: const AppScrollBehavior(),
              initialRoute: '/',
              routes: {
                '/': (context) => const SplashScreen(),
                '/login': (context) => const LoginScreen(),
                '/register': (context) => const RegisterScreen(),
                '/forgot-password': (context) => const ForgotPasswordScreen(),
                '/root': (context) => const RootShell(),
                '/system-status': (context) => const SystemStatusScreen(),
                '/add-module': (context) => const AddModuleScreen(),
                '/rooms': (context) => const RoomsScreen(),
                '/automations': (context) => const AutomationsScreen(),
                '/event-history': (context) => const EventHistoryScreen(),
                '/settings/account': (context) => const AccountScreen(),
                '/settings/notifications': (context) => const NotificationsSettingsScreen(),
                '/settings/language': (context) => const LanguageSettingsScreen(),
              },
            );
          },
        );
      },
    );
  }
}

/// Allows drag-to-scroll with a mouse and trackpad in addition to touch.
/// Flutter's default [MaterialScrollBehavior] excludes mouse/trackpad, so on
/// desktop builds swiping with a mouse button held down does not scroll.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// Hosts the four primary tabs behind a single Material 3 [NavigationBar]:
/// Home, Configuration, Scenarios, Settings (brief: "Application Structure
/// (Main Navigation)"). Each tab is kept alive in an [IndexedStack] so
/// switching tabs preserves scroll position and any in-progress local
/// state.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const List<Widget> _tabs = [
    HomeScreen(),
    ConfigurationScreen(),
    ScenariosScreen(),
    SettingsScreen(),
  ];

  void _onDestinationSelected(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Configuration',
          ),
          NavigationDestination(
            icon: Icon(Icons.flash_on_outlined),
            selectedIcon: Icon(Icons.flash_on),
            label: 'Scenarios',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
