import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../providers/auth_providers.dart';

enum _ResetMethod { email, phone }

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _emailSent = false;
  bool _codeSent = false;
  bool _obscurePassword = true;
  _ResetMethod _method = _ResetMethod.phone;
  // NEW: same resend cooldown as signup — see signup_screen.dart for
  // the full reasoning.
  int _resendSecondsLeft = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  String? get _formattedPhone {
    final digits = _phoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length != 10) return null;
    return '+91$digits';
  }

  String? _passwordStrengthError(String password) {
    if (password.length < 6) return 'Password must be at least 6 characters';
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
    final hasNumber = RegExp(r'\d').hasMatch(password);
    final hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\/~`]').hasMatch(password);
    if (!hasLetter || !hasNumber || !hasSpecialChar) {
      return 'Password must include a letter, a number, and a special character';
    }
    return null;
  }

  Future<void> _onSendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(forgotPasswordNotifierProvider.notifier).sendResetEmail(_emailController.text.trim());
    if (success) {
      setState(() => _emailSent = true);
    } else if (mounted) {
      final error = ref.read(forgotPasswordNotifierProvider).errorMessage;
      // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Something went wrong.')));
      await _showErrorDialog(
        error ?? 'Something went wrong.',
      );
    }
  }



  Future<void> _onSendPhoneCode() async {
    final phone = _formattedPhone;

    if (phone == null) {
      await _showErrorDialog(
        'Enter a valid 10-digit phone number.',
      );
      return;
    }

    final success = await ref
        .read(phonePasswordResetProvider.notifier)
        .sendCode(phone);

    if (success && mounted) {
      setState(() => _codeSent = true);
      _startResendCooldown();
      return;
    }

    if (mounted) {
      final error =
          ref.read(phonePasswordResetProvider).errorMessage;

      if (error != null && error.isNotEmpty) {
        await _showErrorDialog(error);
      }
    }
  }
  // FIXED: same bug as signup — the only "resend" option previously
  // called .reset() first, wiping the resendToken the fix relies on.
  // This stays on the OTP screen and reuses the notifier's existing
  // resendToken correctly.
  Future<void> _onResendPhoneCode() async {
    if (_resendSecondsLeft > 0) return;
    final success = await ref.read(phonePasswordResetProvider.notifier).sendCode(_formattedPhone!);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code resent.')));
      _startResendCooldown();
    }
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendSecondsLeft--);
      if (_resendSecondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _showErrorDialog(String message) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline),
              SizedBox(width: 10),
              Text('Error'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }


  // Future<void> _onResetWithPhoneOtp() async {
  //   if (_codeController.text.trim().length < 4) {
  //     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the code you received.')));
  //     return;
  //   }
  //   final passwordError = _passwordStrengthError(_newPasswordController.text);
  //   if (passwordError != null) {
  //     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(passwordError)));
  //     return;
  //   }
  //   final success = await ref.read(phonePasswordResetProvider.notifier).resetPassword(
  //         smsCode: _codeController.text.trim(),
  //         newPassword: _newPasswordController.text,
  //       );
  //   if (!success && mounted) {
  //     final error = ref.read(phonePasswordResetProvider).errorMessage;
  //     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Could not reset password.')));
  //   }
  //   // On success, router redirect (listening to authStateChangesProvider)
  //   // takes the user to Home automatically — the account now has the
  //   // freshly set password already in place.
  // }

  Future<void> _onResetWithPhoneOtp() async {
    if (_codeController.text.trim().length < 4) {
      await _showErrorDialog(
        'Enter the verification code you received.',
      );
      return;
    }

    final passwordError =
        _passwordStrengthError(_newPasswordController.text);

    if (passwordError != null) {
      await _showErrorDialog(passwordError);
      return;
    }

    final success = await ref
        .read(phonePasswordResetProvider.notifier)
        .resetPassword(
          smsCode: _codeController.text.trim(),
          newPassword: _newPasswordController.text,
        );

    if (!success && mounted) {
      final error =
          ref.read(phonePasswordResetProvider).errorMessage;

      await _showErrorDialog(
        error ?? 'Could not reset password.',
      );

      return;
    }

    // IMPORTANT:
    // resetPasswordWithPhoneOtp() signs the temporary Firebase
    // session out after changing the password.
    //
    // Therefore DO NOT let authStateChanges automatically
    // decide the next screen here.
    if (success && mounted) {
      await _showSuccessDialog(
        'Your password has been changed successfully. Please login with your new password.',
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _showSuccessDialog(String message) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline),
              SizedBox(width: 10),
              Text('Success'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final emailState = ref.watch(forgotPasswordNotifierProvider);
    final phoneState = ref.watch(phonePasswordResetProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<_ResetMethod>(
                  segments: const [
                    ButtonSegment(value: _ResetMethod.email, label: Text('Email'), icon: Icon(Icons.email_outlined)),
                    ButtonSegment(value: _ResetMethod.phone, label: Text('Phone'), icon: Icon(Icons.phone_outlined)),
                  ],
                  selected: {_method},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _method = selection.first;
                      _codeSent = false;
                      _emailSent = false;
                      ref.read(phonePasswordResetProvider.notifier).reset();
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                if (_method == _ResetMethod.email) ...[
                  if (_emailSent) ...[
                    const Icon(Icons.mark_email_read_outlined, size: 64),
                    const SizedBox(height: AppSpacing.md),
                    Text('Check your inbox', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'We\'ve sent a password reset link to ${_emailController.text.trim()}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ] else ...[
                    Text(
                      'Enter the email associated with your account and we\'ll send a reset link.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      key: const ValueKey('email-field'),
                      controller: _emailController,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email is required';
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(label: 'Send Reset Link', isLoading: emailState.isLoading, onPressed: _onSendResetEmail),
                  ],
                ] else ...[
                  if (!_codeSent) ...[
                    Text(
                      'Enter the phone number on your account — we\'ll text you a code to verify it\'s really you before letting you set a new password.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(controller: _phoneController, label: 'Phone Number', hint: '10-digit number', keyboardType: TextInputType.phone),
                    // if (phoneState.errorMessage != null)
                    //   Padding(
                    //     padding: const EdgeInsets.only(top: AppSpacing.sm),
                    //     child: Text(phoneState.errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    //   ),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(label: 'Send Code', isLoading: phoneState.isSendingCode, onPressed: _onSendPhoneCode),
                  ] else ...[
                    Text('Code sent to +91 ${_phoneController.text.trim()}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(controller: _codeController, label: 'Verification Code', keyboardType: TextInputType.number),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      key: const ValueKey('phone-field'),
                      controller: _newPasswordController,
                      label: 'New Password',
                      hint: 'Letter, number & special character',
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    // if (phoneState.errorMessage != null)
                    //   Padding(
                    //     padding: const EdgeInsets.only(top: AppSpacing.sm),
                    //     child: Text(phoneState.errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    //   ),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(label: 'Verify & Set Password', isLoading: phoneState.isResetting, onPressed: _onResetWithPhoneOtp),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: _resendSecondsLeft > 0 ? null : _onResendPhoneCode,
                          child: Text(_resendSecondsLeft > 0 ? 'Resend in ${_resendSecondsLeft}s' : 'Resend code'),
                        ),
                        const Text('•'),
                        TextButton(
                          onPressed: () {
                            _resendTimer?.cancel();
                            ref.read(phonePasswordResetProvider.notifier).reset();
                            setState(() {
                              _codeSent = false;
                              _codeController.clear();
                              _resendSecondsLeft = 0;
                            });
                          },
                          child: const Text('Change number'),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}