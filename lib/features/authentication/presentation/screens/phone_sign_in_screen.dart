import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../providers/auth_providers.dart';

const _green = Color(0xFF2E7D32);

/// Combines phone entry and OTP verification in one screen rather than
/// two separate routes — simpler to reason about, and the "resend" /
/// "change number" actions both naturally just reset back to the first
/// stage instead of needing real navigation.
class PhoneSignInScreen extends ConsumerStatefulWidget {
  const PhoneSignInScreen({super.key});

  @override
  ConsumerState<PhoneSignInScreen> createState() => _PhoneSignInScreenState();
}

class _PhoneSignInScreenState extends ConsumerState<PhoneSignInScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String? get _formattedPhone {
    final digits = _phoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length != 10) return null;
    // India-only for now, matching where this business operates — a
    // country picker would be the natural next step if that changes.
    return '+91$digits';
  }

  Future<void> _sendCode() async {
    final phone = _formattedPhone;
    if (phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid 10-digit phone number.')));
      return;
    }
    final success = await ref.read(phoneAuthProvider.notifier).sendCode(phone);
    if (success && mounted) setState(() => _codeSent = true);
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.trim().length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the code you received.')));
      return;
    }
    final success = await ref.read(phoneAuthProvider.notifier).verifyCode(_codeController.text.trim());
    // No explicit navigation on success — the router's own redirect
    // logic picks up the now-signed-in state and moves on by itself,
    // same as every other sign-in path in this app.
    if (!success) return;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final state = ref.watch(phoneAuthProvider);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Sign in with Phone'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              if (!_codeSent) ...[
                const Text('Enter your phone number', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text("We'll send a one-time code to verify it's you.", style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 24),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: const InputDecoration(prefixText: '+91  ', labelText: 'Phone number', counterText: ''),
                ),
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(state.errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: state.isSendingCode ? null : _sendCode,
                  child: state.isSendingCode
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Send Code'),
                ),
              ] else ...[
                const Text('Enter the code', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Sent to +91 ${_phoneController.text.trim()}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 24),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(counterText: '', hintText: '000000'),
                ),
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(state.errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: state.isVerifying ? null : _verifyCode,
                  child: state.isVerifying
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Verify & Continue'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    ref.read(phoneAuthProvider.notifier).reset();
                    setState(() {
                      _codeSent = false;
                      _codeController.clear();
                    });
                  },
                  child: const Text('Change number / resend'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
