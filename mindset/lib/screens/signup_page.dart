import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/settings_widgets.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({
    super.key,
    required this.onBack,
    required this.onLogin,
    required this.onAuthenticated,
  });

  final VoidCallback onBack;
  final VoidCallback onLogin;
  final VoidCallback onAuthenticated;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if ((value?.trim() ?? '').length < 2) {
      return 'Enter your full name.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (email.isEmpty) {
      return 'Enter your email address.';
    }
    if (!pattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.length < 6) {
      return 'Use at least 6 characters.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if ((value ?? '') != _passwordController.text) {
      return 'Passwords do not match.';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);
    try {
      await _authService.createAccount(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) {
        widget.onAuthenticated();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_authService.errorMessage(error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormShell(
      title: 'Create your space',
      subtitle: 'A private account for daily emotional reflection.',
      leading: BackButton(onPressed: _loading ? null : widget.onBack),
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _nameController,
                  label: 'Full name',
                  hint: 'Your name',
                  icon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  validator: _validateName,
                  enabled: !_loading,
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: _emailController,
                  label: 'Email address',
                  hint: 'student@example.com',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                  enabled: !_loading,
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Create a password',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  validator: _validatePassword,
                  enabled: !_loading,
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm password',
                  hint: 'Re-enter your password',
                  icon: Icons.lock_person_outlined,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  validator: _validateConfirmPassword,
                  onSubmitted: (_) => _submit(),
                  enabled: !_loading,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const PrivacyNotice(
          icon: Icons.verified_user_outlined,
          title: 'Reflection-first design',
          text:
              'MindSet keeps journal content private and separates optional behaviour signals from what you write.',
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.person_add_alt_1),
          label: Text(_loading ? 'Creating account...' : 'Create account'),
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: _loading ? null : widget.onLogin,
          child: const Text('I already have an account'),
        ),
      ],
    );
  }
}
