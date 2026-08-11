import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';

class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  ConsumerState<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // NEW: this used to only check length (>= 6) — much weaker than
  // signup's actual rule, so a password that would've been rejected
  // when first creating the account could be freely set here via
  // Change Password, silently bypassing the strength requirement.
  // Copied verbatim from signup_screen.dart's _passwordStrengthError
  // so both places enforce exactly the same rule.
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref.read(changePasswordNotifierProvider.notifier).changePassword(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
        );

    if (!mounted) return;

    // Closes the dialog and hands the result back to whoever opened it —
    // showChangePasswordDialog() below uses this to pop back to Profile
    // and show the confirmation snackbar there. (Previously this dialog
    // stayed open with an inline success banner instead — swap this
    // Navigator.pop for a setState(() => _success = true) if you'd
    // rather go back to that behavior.)
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(changePasswordNotifierProvider);

    return AlertDialog(
      title: const Text('Change Password'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    state.errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              TextFormField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  return _passwordStrengthError(v);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm New Password'),
                validator: (v) => v != _newPasswordController.text ? 'Passwords do not match' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: state.isLoading ? null : _submit,
          child: state.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }
}

Future<bool?> showChangePasswordDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (_) => const ChangePasswordDialog(),
  );
}
