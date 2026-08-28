import 'package:flutter/material.dart';

import 'login_page.dart';
import 'signup_page.dart';
import 'welcome_page.dart';

enum AuthPage { welcome, login, signUp }

class AuthFlow extends StatefulWidget {
  const AuthFlow({
    super.key,
    required this.darkMode,
    required this.onThemeChanged,
    required this.onAuthenticated,
  });

  final bool darkMode;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onAuthenticated;

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  AuthPage _page = AuthPage.welcome;

  void _show(AuthPage page) {
    setState(() => _page = page);
  }

  @override
  Widget build(BuildContext context) {
    final child = switch (_page) {
      AuthPage.welcome => WelcomePage(
        darkMode: widget.darkMode,
        onThemeChanged: widget.onThemeChanged,
        onLogin: () => _show(AuthPage.login),
        onCreateAccount: () => _show(AuthPage.signUp),
      ),
      AuthPage.login => LoginPage(
        onBack: () => _show(AuthPage.welcome),
        onCreateAccount: () => _show(AuthPage.signUp),
        onAuthenticated: widget.onAuthenticated,
      ),
      AuthPage.signUp => SignUpPage(
        onBack: () => _show(AuthPage.welcome),
        onLogin: () => _show(AuthPage.login),
        onAuthenticated: widget.onAuthenticated,
      ),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: KeyedSubtree(key: ValueKey(_page), child: child),
    );
  }
}
