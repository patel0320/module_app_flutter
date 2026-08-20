// lib/screens/splash_screen.dart
//
// Branding screen shown on launch while the (simulated) session is
// bootstrapped, then forwards to the mandatory sign-in flow (brief section
// 3.1: "On first launch, the application will request the creation of an
// account...").
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: onSurface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.bolt, color: Theme.of(context).colorScheme.surface, size: 52),
            ),
            const SizedBox(height: 24),
            Text(
              'RelayControl',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Relays · Dimmers · Scenarios',
              style: TextStyle(color: onSurface.withOpacity(0.6)),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.6, color: onSurface.withOpacity(0.4)),
            ),
          ],
        ),
      ),
    );
  }
}
