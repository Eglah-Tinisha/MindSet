import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth_flow.dart';
import 'screens/mindset_shell.dart';
import 'services/auth_service.dart';
import 'theme/mindset_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MindSetApp());
}

class MindSetApp extends StatefulWidget {
  const MindSetApp({super.key});

  @override
  State<MindSetApp> createState() => _MindSetAppState();
}

class _MindSetAppState extends State<MindSetApp> {
  bool _darkMode = false;
  bool _signedIn = FirebaseAuth.instance.currentUser != null;

  void _toggleTheme(bool value) {
    setState(() => _darkMode = value);
  }

  void _setSignedIn(bool value) {
    setState(() => _signedIn = value);
  }

  Future<void> _signOut() async {
    await AuthService().signOut();
    _setSignedIn(false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MindSet',
      theme: MindSetTheme.light,
      darkTheme: MindSetTheme.dark,
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      home: _signedIn
          ? MindSetShell(
              darkMode: _darkMode,
              onThemeChanged: _toggleTheme,
              onSignOut: _signOut,
            )
          : AuthFlow(
              darkMode: _darkMode,
              onThemeChanged: _toggleTheme,
              onAuthenticated: () => _setSignedIn(true),
            ),
    );
  }
}
