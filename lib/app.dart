import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/navigation/main_shell.dart';

class _SystemStatusPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System Status')),
      body: const Center(child: Text('Error & event log (30 days)')),
    );
  }
}

class _ScenarioSliderPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual dimming slider')),
      body: StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Slider(
                value: 30,
                min: 0,
                max: 100,
                divisions: 100,
                label: '30%',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              const Text('Brightness'),
            ],
          ),
        ),
      ),
    );
  }
}

class ModuleApp extends StatelessWidget {
  const ModuleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Soleux Device Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: const Locale('en'),
      supportedLocales: const [
        Locale('en'),
        Locale('ro'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      onGenerateRoute: (settings) {
        final fallback = MaterialPageRoute<void>(
          builder: (_) {
            switch (settings.name) {
              case '/system-status':
                return _SystemStatusPage();
              case '/scenario-slider':
                return _ScenarioSliderPage();
              default:
                return const MainShell();
            }
          },
        );
        return fallback;
      },
      home: const MainShell(),
    );
  }
}
