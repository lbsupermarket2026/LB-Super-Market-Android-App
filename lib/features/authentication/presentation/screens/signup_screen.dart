import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../providers/auth_providers.dart';

enum _VerifyMethod { email, phone }

/// Name, email, and phone are all collected together up front — no
/// separate "sign up with email" vs "sign up with phone" flows. The
/// only choice is HOW to verify: email sends a click-through link
/// (already proven, no extra cost); phone sends a real SMS OTP. Both
/// paths end with the exact same account, holding both the email and
/// the phone number either way.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  bool _obscurePassword = true;
  _VerifyMethod _verifyMethod = _VerifyMethod.email;
  bool _codeSent = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
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

  String? get _formattedPhone {
    final digits = _phoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length != 10) return null;
    return '+91$digits';
  }

  Future<void> _onSignUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(signUpNotifierProvider.notifier).signUp(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
        );
    if (!success && mounted) {
      final error = ref.read(signUpNotifierProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Sign up failed.')));
    }
    // On success, router redirect handles navigation.
  }

  Future<void> _onSendCode() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _formattedPhone;
    if (phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid 10-digit phone number.')));
      return;
    }
    final success = await ref.read(phoneSignUpProvider.notifier).sendCode(phone);
    if (success && mounted) setState(() => _codeSent = true);
  }

  Future<void> _onCompletePhoneSignUp() async {
    if (_codeController.text.trim().length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the code you received.')));
      return;
    }
    final phone = _formattedPhone;
    if (phone == null) return;
    final success = await ref.read(phoneSignUpProvider.notifier).completeSignUp(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: phone,
          password: _passwordController.text,
          smsCode: _codeController.text.trim(),
        );
    if (!success && mounted) {
      final error = ref.read(phoneSignUpProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Sign up failed.')));
    }
    // On success, router redirect handles navigation.
  }

  @override
  Widget build(BuildContext context) {
    final signUpState = ref.watch(signUpNotifierProvider);
    final phoneSignUpState = ref.watch(phoneSignUpProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up as a New Customer')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Phone number is required';
                    if (v.trim().length < 10) return 'Enter a valid phone number';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Letter, number & special character',
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    return _passwordStrengthError(v);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Verify via', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<_VerifyMethod>(
                  segments: const [
                    ButtonSegment(value: _VerifyMethod.email, label: Text('Email link'), icon: Icon(Icons.email_outlined)),
                    ButtonSegment(value: _VerifyMethod.phone, label: Text('Phone OTP'), icon: Icon(Icons.sms_outlined)),
                  ],
                  selected: {_verifyMethod},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _verifyMethod = selection.first;
                      _codeSent = false;
                      ref.read(phoneSignUpProvider.notifier).reset();
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                if (_verifyMethod == _VerifyMethod.email) ...[
                  PrimaryButton(
                    label: 'Sign Up',
                    isLoading: signUpState.isLoading,
                    onPressed: _onSignUpWithEmail,
                  ),
                ] else ...[
                  if (!_codeSent) ...[
                    PrimaryButton(
                      label: 'Send Code',
                      isLoading: phoneSignUpState.isSendingCode,
                      onPressed: _onSendCode,
                    ),
                  ] else ...[
                    Text('Code sent to +91 ${_phoneController.text.trim()}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _codeController,
                      label: 'Verification Code',
                      keyboardType: TextInputType.number,
                    ),
                    if (phoneSignUpState.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(phoneSignUpState.errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: 'Verify & Create Account',
                      isLoading: phoneSignUpState.isCompleting,
                      onPressed: _onCompletePhoneSignUp,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () {
                        ref.read(phoneSignUpProvider.notifier).reset();
                        setState(() {
                          _codeSent = false;
                          _codeController.clear();
                        });
                      },
                      child: const Text('Change number / resend'),
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