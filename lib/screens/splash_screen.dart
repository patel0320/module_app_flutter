// lib/screens/splash_screen.dart
//
// Branding screen shown on launch while the (simulated) session is
// bootstrapped, then forwards to the mandatory sign-in flow (brief section
// 3.1: "On first launch, the application will request the creation of an
// account...").
import 'package:flutter/material.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';

import '../services/session_store.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Module fleet + live status are loaded by the root shell once it mounts
    // (see _RootShellState.initState); here we only pick the landing route.
    Future.delayed(const Duration(milliseconds: 1400), () async {
      // A persisted sign-in session (see SessionStore) takes the user straight
      // back to the main shell after the OS killed the process in the
      // background; first-time / signed-out launches go to the sign-in flow.
      await SessionStore.shared.init();
      if (!mounted) return;
      Navigator.of(context).restorablePushReplacementNamed(
          SessionStore.shared.signedIn ? '/root' : '/login');
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
            // Text(
            //   l10n.splashAppName,
            //   style: Theme.of(context)
            //       .textTheme
            //       .headlineSmall
            //       ?.copyWith(fontWeight: FontWeight.w800),
            // ),
            // const SizedBox(height: 8),
            Text(
              l10n.splashTagline,
              style: TextStyle(color: onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  strokeWidth: 2.6, color: onSurface.withValues(alpha: 0.4)),
            ),
          ],
        ),
      ),
    );
  }
}
