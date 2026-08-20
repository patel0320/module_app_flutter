// lib/screens/forgot_password_screen.dart
//
// Standard password-reset flow (brief section 3.1: "Password Recovery: A
// standard password reset functionality via email is implemented"). The
// "send" action only flips local UI state - no email is actually sent.
import 'package:flutter/material.dart';

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
        const SnackBar(content: Text('Please enter your email address.')),
      );
      return;
    }
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_sent) ...[
                Text(
                  'Enter the email address associated with your account and we will '
                  'send you a link to reset your password.',
                  style: TextStyle(color: onSurface.withOpacity(0.6)),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: _sendResetLink, child: const Text('Send reset link')),
              ] else ...[
                const SizedBox(height: 24),
                Icon(Icons.mark_email_read_outlined, size: 56, color: onSurface),
                const SizedBox(height: 16),
                Text('Check your inbox', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'If an account exists for ${_emailController.text.trim()}, a reset link has been sent.',
                  style: TextStyle(color: onSurface.withOpacity(0.6)),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to Sign In'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
