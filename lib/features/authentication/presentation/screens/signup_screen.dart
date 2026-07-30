import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../providers/auth_providers.dart';

const _green = Color(0xFF2E7D32);

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

enum _SignupMethod { email, phone }

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  bool _obscurePassword = true;
  _SignupMethod _method = _SignupMethod.email;
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
    // On success, router redirect (listening to authStateChangesProvider)
    // takes the user to /home automatically.
  }

  Future<void> _onSendCode() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your name first.')));
      return;
    }
    final phone = _formattedPhone;
    if (phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid 10-digit phone number.')));
      return;
    }
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters.')));
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
          phone: phone,
          password: _passwordController.text,
          smsCode: _codeController.text.trim(),
        );
    if (!success && mounted) {
      final error = ref.read(phoneSignUpProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Sign up failed.')));
    }
    // On success, router redirect handles navigation, same as email path.
  }

  @override
  Widget build(BuildContext context) {
    final signUpState = ref.watch(signUpNotifierProvider);
    final phoneSignUpState = ref.watch(phoneSignUpProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Method toggle — phone gets OTP-verified once right here at
                // signup; after that, both methods behave identically (email
                // or phone + password, no OTP needed again for phone).
                SegmentedButton<_SignupMethod>(
                  segments: const [
                    ButtonSegment(value: _SignupMethod.email, label: Text('Email'), icon: Icon(Icons.email_outlined)),
                    ButtonSegment(value: _SignupMethod.phone, label: Text('Phone'), icon: Icon(Icons.phone_outlined)),
                  ],
                  selected: {_method},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _method = selection.first;
                      _codeSent = false;
                      ref.read(phoneSignUpProvider.notifier).reset();
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: AppSpacing.md),

                if (_method == _SignupMethod.email) ...[
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
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      if (v.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Sign Up',
                    isLoading: signUpState.isLoading,
                    onPressed: _onSignUpWithEmail,
                  ),
                ] else ...[
                  if (!_codeSent) ...[
                    AppTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      hint: '10-digit number',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _passwordController,
                      label: 'Password',
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    if (phoneSignUpState.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(phoneSignUpState.errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    const SizedBox(height: AppSpacing.xl),
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
                    const SizedBox(height: AppSpacing.xl),
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
