// lib/screens/splash_screen.dart
//
// Pure branding screen shown while the (simulated) session is bootstrapped.
// It performs no navigation itself: the landing-route handoff is owned by
// [AppLifecycleGate] (see lib/main.dart), which forwards past this screen on a
// cold start and re-checks on every foreground resume so the app can never be
// stuck here after a background/foreground cycle.
import 'package:flutter/material.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
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
