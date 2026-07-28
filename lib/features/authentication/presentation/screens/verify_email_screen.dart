import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';

const _green = Color(0xFF2E7D32);

/// Shown when signed in via email/password but Firebase's emailVerified
/// flag is still false. The router only sends users here right after
/// signup — this doesn't block anyone who verified previously, since
/// emailVerified is checked fresh each time the auth stream re-emits.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _isChecking = false;
  bool _isResending = false;
  String? _message;

  Future<void> _checkVerified() async {
    setState(() {
      _isChecking = true;
      _message = null;
    });
    final result = await ref.read(authRepositoryProvider).refreshAndCheckEmailVerified();
    if (!mounted) return;
    final verified = result.match((_) => false, (v) => v);
    setState(() {
      _isChecking = false;
      _message = verified ? null : 'Still not verified — check your inbox (and spam folder) for the link.';
    });
    if (verified) {
      // Nudges the auth stream to re-evaluate now that emailVerified is
      // true — the router picks this up and moves on automatically.
      ref.invalidate(authStateChangesProvider);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _isResending = true;
      _message = null;
    });
    final result = await ref.read(authRepositoryProvider).resendEmailVerification();
    if (!mounted) return;
    setState(() {
      _isResending = false;
      _message = result.match((f) => f.message, (_) => 'Verification email sent — check your inbox.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8ED),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_unread_outlined, size: 72, color: _green),
              const SizedBox(height: 20),
              const Text('Verify your email', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(
                'We sent a verification link to ${user?.email ?? 'your email'}. Tap the link, then come back here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 24),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_message!, textAlign: TextAlign.center, style: const TextStyle(color: _green, fontSize: 13)),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _isChecking ? null : _checkVerified,
                  child: _isChecking
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("I've verified — continue"),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isResending ? null : _resend,
                child: Text(_isResending ? 'Sending…' : 'Resend verification email'),
              ),
              TextButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                child: const Text('Sign out', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
