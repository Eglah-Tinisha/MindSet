import 'package:flutter/material.dart';

import '../models/models.dart';

class MindSetTheme {
  static const sage = Color(0xFF7A9E7E);
  static const darkSage = Color(0xFF68866C);
  static const paleGreen = Color(0xFFBFD8BD);
  static const olive = Color(0xFF8AA68D);
  static const warmBeige = Color(0xFFF7F7F2);
  static const cream = Color(0xFFFCFCF8);
  static const lightSageTint = Color(0xFFEEF3ED);
  static const charcoal = Color(0xFF121212);
  static const darkCard = Color(0xFF1E2421);
  static const softBlack = Color(0xFF222827);
  static const textMain = Color(0xFF2E3A34);
  static const textSecondary = Color(0xFF4F5A55);
  static const textBody = Color(0xFF5B635F);
  static const border = Color(0xFFDDE5DC);
  static const divider = Color(0xFFE8ECE7);
  static const success = Color(0xFF8EB897);
  static const warning = Color(0xFFF0B67F);
  static const error = Color(0xFFD98C8C);
  static const info = Color(0xFF7DA9E6);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: sage,
      brightness: Brightness.light,
      primary: sage,
      secondary: paleGreen,
      surface: cream,
      error: error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: warmBeige,
      colorScheme: colorScheme,
      dividerColor: divider,
      fontFamily: 'Inter',
      textTheme: _textTheme(
        main: textMain,
        secondary: textSecondary,
        body: textBody,
        caption: const Color(0xFF9CA3AF),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: warmBeige,
        foregroundColor: textMain,
        centerTitle: false,
      ),
      inputDecorationTheme: _inputTheme(
        fill: Colors.white,
        borderColor: border,
        hintColor: const Color(0xFF9CA3AF),
      ),
      cardTheme: CardThemeData(
        color: cream,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: border),
        ),
      ),
      filledButtonTheme: _filledButtonTheme(sage, Colors.white),
      outlinedButtonTheme: _outlinedButtonTheme(sage),
      switchTheme: _switchTheme(sage, paleGreen),
      navigationBarTheme: _navigationBarTheme(
        background: lightSageTint,
        selected: sage,
        unselected: textBody,
        indicator: paleGreen,
      ),
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: success,
      brightness: Brightness.dark,
      primary: success,
      secondary: const Color(0xFF5E7460),
      surface: darkCard,
      error: const Color(0xFFE09A9A),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: charcoal,
      colorScheme: colorScheme,
      dividerColor: const Color(0xFF2F3533),
      fontFamily: 'Inter',
      textTheme: _textTheme(
        main: const Color(0xFFF3F4F6),
        secondary: const Color(0xFFD1D5DB),
        body: const Color(0xFFD1D5DB),
        caption: const Color(0xFF9CA3AF),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: charcoal,
        foregroundColor: Color(0xFFF3F4F6),
        centerTitle: false,
      ),
      inputDecorationTheme: _inputTheme(
        fill: softBlack,
        borderColor: const Color(0xFF374151),
        hintColor: const Color(0xFF9CA3AF),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF374151)),
        ),
      ),
      filledButtonTheme: _filledButtonTheme(success, charcoal),
      outlinedButtonTheme: _outlinedButtonTheme(success),
      switchTheme: _switchTheme(success, const Color(0xFF5E7460)),
      navigationBarTheme: _navigationBarTheme(
        background: const Color(0xFF171B18),
        selected: success,
        unselected: const Color(0xFF9CA3AF),
        indicator: const Color(0xFF2B3430),
      ),
    );
  }

  static TextTheme _textTheme({
    required Color main,
    required Color secondary,
    required Color body,
    required Color caption,
  }) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 32,
        height: 1.12,
        fontWeight: FontWeight.w700,
        color: main,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 24,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: main,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 20,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: main,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: secondary,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: body,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: body,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: main,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w500,
        color: caption,
      ),
    );
  }

  static InputDecorationTheme _inputTheme({
    required Color fill,
    required Color borderColor,
    required Color hintColor,
  }) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      hintStyle: TextStyle(color: hintColor),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: sage, width: 1.4),
      ),
    );
  }

  static FilledButtonThemeData _filledButtonTheme(
    Color background,
    Color foreground,
  ) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(Color color) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static SwitchThemeData _switchTheme(Color selected, Color track) {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return selected;
        }
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return track.withValues(alpha: 0.45);
        }
        return Colors.grey.withValues(alpha: 0.25);
      }),
    );
  }

  static NavigationBarThemeData _navigationBarTheme({
    required Color background,
    required Color selected,
    required Color unselected,
    required Color indicator,
  }) {
    return NavigationBarThemeData(
      backgroundColor: background,
      indicatorColor: indicator,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final isSelected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: 'Inter',
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12,
          color: isSelected ? selected : unselected,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final isSelected = states.contains(WidgetState.selected);
        return IconThemeData(color: isSelected ? selected : unselected);
      }),
    );
  }
}

class MoodPalette {
  static const happy = Color(0xFF8EB897);
  static const calm = Color(0xFFBFD8BD);
  static const neutral = Color(0xFFD8D8D8);
  static const sad = Color(0xFFA7B8C4);
  static const stress = Color(0xFFF0B67F);
  static const angry = Color(0xFFD98C8C);

  static const moods = [
    MoodOption(
      label: 'Happy',
      icon: Icons.sentiment_very_satisfied,
      color: happy,
    ),
    MoodOption(label: 'Calm', icon: Icons.spa_outlined, color: calm),
    MoodOption(label: 'Neutral', icon: Icons.sentiment_neutral, color: neutral),
    MoodOption(label: 'Sad', icon: Icons.sentiment_dissatisfied, color: sad),
    MoodOption(label: 'Stress', icon: Icons.psychology_outlined, color: stress),
    MoodOption(
      label: 'Angry',
      icon: Icons.sentiment_very_dissatisfied,
      color: angry,
    ),
  ];
}
