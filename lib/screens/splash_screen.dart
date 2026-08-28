// lib/screens/splash_screen.dart
//
// Branding screen shown on launch while the (simulated) session is
// bootstrapped, then forwards to the mandatory sign-in flow (brief section
// 3.1: "On first launch, the application will request the creation of an
// account...").
import 'package:flutter/material.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';

import '../services/module_status/module_status_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // On app open: load the persisted module fleet into the app-wide store,
    // then connect to every configured module and fetch its live status over
    // the PROTOCOLS.md §1 TCP protocol. Fire-and-forget so bootstrap never
    // blocks navigation; every screen watches the same store and rebuilds as
    // status arrives (online/offline, temperature, output states).
    ModuleStatusService.shared.refreshAll().ignore();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 300,
              height: 92,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.power,
                size: 92,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.splashAppName,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.splashTagline,
              style: TextStyle(color: onSurface.withOpacity(0.6)),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  strokeWidth: 2.6, color: onSurface.withOpacity(0.4)),
            ),
          ],
        ),
      ),
    );
  }
}
