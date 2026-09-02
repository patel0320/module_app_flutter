// lib/main.dart
//
// App entry point: Material 3 theme wiring and top-level navigation.
// This is a fully static UI prototype - there is no backend, network, or
// database call anywhere in this codebase. All data is hardcoded in
// lib/data/mock_data.dart and mutated only in local widget state.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';

import 'screens/account_screen.dart';
import 'screens/add_module_screen.dart';
import 'screens/appearance_settings_screen.dart';
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
import 'services/automation_scheduler.dart';
import 'services/automation_store.dart';
import 'services/room_store.dart';
import 'services/module_status/background_status_worker.dart';
import 'services/module_status/module_status_scheduler.dart';
import 'services/module_status/module_status_service.dart';
import 'services/notification_monitor.dart';
import 'services/notification_service.dart';
import 'services/scenario_store.dart';
import 'services/session_store.dart';
import 'services/settings_store.dart';
import 'theme/app_theme.dart';
import 'theme/theme_palettes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Kick off loading the persisted room, scenario, automation and module
  // lists before the first frame so the Rooms / Scenarios / Automations /
  // Home screens reflect storage immediately.
  RoomStore.shared.init();
  ScenarioStore.shared.init();
  AutomationStore.shared.init();
  SettingsStore.shared.init();
  SessionStore.shared.init();
  // Start the automation runtime: it arms daily timers for time-of-day rules
  // and watches the module fleet for device-state rules, firing them through
  // the scenario engine into the event history (see AutomationScheduler).
  AutomationScheduler.shared.start();
  // Register the OS background worker that polls module online/offline status
  // after the app is suspended, then start the lifecycle-aware scheduler:
  // persistent sockets while foreground, timed polling while backgrounded.
  BackgroundStatusWorker.initialize().ignore();
  ModuleStatusScheduler.shared.start();
  // Initialise local notifications and start watching the module store so
  // offline/online, temperature and output-duration alerts fire while the app
  // is open (the background worker raises them while it is suspended).
  // The foreground observer is only registered on this (main) isolate, so
  // alerts never pop a banner while the app is visible; they still surface as
  // OS notifications once the app is backgrounded.
  LocalNotificationService.shared.initialize().ignore();
  LocalNotificationService.shared.startForegroundMonitoring();
  NotificationMonitor.shared.start();
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
            return ValueListenableBuilder<Locale>(
              valueListenable: appLocaleNotifier,
              builder: (context, locale, _) {
                return MaterialApp(
                  onGenerateTitle: (context) =>
                      AppLocalizations.of(context).appTitle,
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightFor(themeId),
                  darkTheme: AppTheme.darkFor(themeId),
                  themeMode: mode,
                  locale: locale,
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  scrollBehavior: const AppScrollBehavior(),
                  restorationScopeId: 'app',
                  initialRoute: '/',
                  routes: {
                    '/': (context) => const SplashScreen(),
                    '/login': (context) => const LoginScreen(),
                    '/register': (context) => const RegisterScreen(),
                    '/forgot-password': (context) =>
                        const ForgotPasswordScreen(),
                    '/root': (context) => const RootShell(),
                    '/system-status': (context) => const SystemStatusScreen(),
                    '/add-module': (context) => const AddModuleScreen(),
                    '/rooms': (context) => const RoomsScreen(),
                    '/automations': (context) => const AutomationsScreen(),
                    '/event-history': (context) => const EventHistoryScreen(),
                    '/settings/account': (context) => const AccountScreen(),
                    '/settings/notifications': (context) =>
                        const NotificationsSettingsScreen(),
                    '/settings/language': (context) =>
                        const LanguageSettingsScreen(),
                    '/settings/appearance': (context) =>
                        const AppearanceSettingsScreen(),
                  },
                );
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

class _RootShellState extends State<RootShell> with RestorationMixin {
  /// Persisted across process death so the last visited tab is restored.
  final RestorableInt _tabIndex = RestorableInt(0);

  @override
  String get restorationId => 'root_tabs';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_tabIndex, 'selected_tab');
  }

  @override
  void initState() {
    super.initState();
    // Connect to every configured module and pull a fresh status dump once the
    // shell is up. Placed here rather than the splash because on state
    // restoration the splash route is skipped entirely - the navigator restores
    // straight into '/root'.
    ModuleStatusService.shared.refreshAll().ignore();
  }

  @override
  void dispose() {
    _tabIndex.dispose();
    super.dispose();
  }

  static const List<Widget> _tabs = [
    HomeScreen(),
    ConfigurationScreen(),
    ScenariosScreen(),
    SettingsScreen(),
  ];

  void _onDestinationSelected(int index) =>
      setState(() => _tabIndex.value = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tabIndex.value, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex.value,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: AppLocalizations.of(context).tabHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.tune_outlined),
            selectedIcon: const Icon(Icons.tune),
            label: AppLocalizations.of(context).tabConfiguration,
          ),
          NavigationDestination(
            icon: const Icon(Icons.flash_on_outlined),
            selectedIcon: const Icon(Icons.flash_on),
            label: AppLocalizations.of(context).tabScenarios,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: AppLocalizations.of(context).tabSettings,
          ),
        ],
      ),
    );
  }
}
