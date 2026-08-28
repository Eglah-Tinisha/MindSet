import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class LocalStore {
  static const _legacyEntriesKey = 'mindset.entries';
  static const _settingsKey = 'mindset.settings';

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) {
      return const AppSettings();
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return const AppSettings();
    }

    return AppSettings.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<void> clearLegacyEntries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyEntriesKey);
  }
}
