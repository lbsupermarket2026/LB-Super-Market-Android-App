import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../providers/auth_providers.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(forgotPasswordNotifierProvider.notifier).sendResetEmail(_emailController.text.trim());
    if (success) {
      setState(() => _emailSent = true);
    } else if (mounted) {
      final error = ref.read(forgotPasswordNotifierProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Something went wrong.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPasswordNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _emailSent
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.mark_email_read_outlined, size: 64),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Check your inbox',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'We\'ve sent a password reset link to ${_emailController.text.trim()}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Enter the email associated with your account and we\'ll send a reset link.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),
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
                      const SizedBox(height: AppSpacing.lg),
                      PrimaryButton(
                        label: 'Send Reset Link',
                        isLoading: state.isLoading,
                        onPressed: _onSubmit,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
