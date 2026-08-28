import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/common_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onBack,
    required this.onCreateAccount,
    required this.onAuthenticated,
  });

  final VoidCallback onBack;
  final VoidCallback onCreateAccount;
  final VoidCallback onAuthenticated;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  bool _resettingPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
    if ((value ?? '').isEmpty) {
      return 'Enter your password.';
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
      await _authService.signIn(
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

  Future<void> _sendPasswordReset() async {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    if (_validateEmail(email) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email address first.')),
      );
      return;
    }

    setState(() => _resettingPassword = true);
    try {
      await _authService.sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_authService.errorMessage(error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _resettingPassword = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormShell(
      title: 'Welcome back',
      subtitle: 'Continue your reflection practice.',
      leading: BackButton(onPressed: _loading ? null : widget.onBack),
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                const SizedBox(height: 14),
                AppTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Enter your password',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  validator: _validatePassword,
                  onSubmitted: (_) => _submit(),
                  enabled: !_loading,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading || _resettingPassword
                        ? null
                        : _sendPasswordReset,
                    child: Text(
                      _resettingPassword
                          ? 'Sending reset email...'
                          : 'Forgot password?',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(_loading ? 'Checking credentials...' : 'Log in'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: _loading ? null : widget.onCreateAccount,
          child: const Text('Create a new account'),
        ),
      ],
    );
  }
}
