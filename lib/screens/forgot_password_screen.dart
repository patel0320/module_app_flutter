// lib/screens/forgot_password_screen.dart
//
// Standard password-reset flow (brief section 3.1: "Password Recovery: A
// standard password reset functionality via email is implemented"). The
// "send" action only flips local UI state - no email is actually sent.
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _sendResetLink() {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).forgotEnterEmail)),
      );
      return;
    }
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.forgotTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_sent) ...[
                Text(
                  l10n.forgotDesc,
                  style: TextStyle(color: onSurface.withOpacity(0.6)),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: l10n.loginEmail, prefixIcon: const Icon(Icons.mail_outline)),
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: _sendResetLink, child: Text(l10n.forgotSend)),
              ] else ...[
                const SizedBox(height: 24),
                Icon(Icons.mark_email_read_outlined, size: 56, color: onSurface),
                const SizedBox(height: 16),
                Text(l10n.forgotCheckInbox, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  l10n.forgotSentMsg(_emailController.text.trim()),
                  style: TextStyle(color: onSurface.withOpacity(0.6)),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.forgotBackToSignIn),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
