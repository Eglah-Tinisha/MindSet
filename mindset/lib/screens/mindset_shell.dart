import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/journal_store.dart';
import '../services/local_store.dart';
import 'dashboard_page.dart';
import 'insights_page.dart';
import 'journal_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';

class MindSetShell extends StatefulWidget {
  const MindSetShell({
    super.key,
    required this.darkMode,
    required this.onThemeChanged,
    required this.onSignOut,
  });

  final bool darkMode;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onSignOut;

  @override
  State<MindSetShell> createState() => _MindSetShellState();
}

class _MindSetShellState extends State<MindSetShell> {
  final AuthService _authService = AuthService();
  final LocalStore _localStore = LocalStore();
  final JournalStore _journalStore = JournalStore();
  StreamSubscription<List<JournalEntry>>? _entriesSubscription;
  int _selectedIndex = 0;
  bool _loading = true;
  List<JournalEntry> _entries = const [];
  AppSettings _settings = const AppSettings();
  JournalEntry? _entryToOpen;
  int _entryOpenRequest = 0;
  int _journalResetRequest = 0;

  @override
  void initState() {
    super.initState();
    _loadAccountState();
  }

  @override
  void dispose() {
    _entriesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAccountState() async {
    try {
      await _authService.ensureUserProfile();
      await _localStore.clearLegacyEntries();
      final settings = await _localStore.loadSettings();
      final entries = await _journalStore.loadEntries();
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = entries;
        _settings = settings;
        _loading = false;
      });
      _watchAccountEntries();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load account journals: $error')),
      );
    }
  }

  void _watchAccountEntries() {
    _entriesSubscription?.cancel();
    _entriesSubscription = _journalStore.watchEntries().listen(
      (entries) {
        if (!mounted) {
          return;
        }
        setState(() => _entries = entries);
      },
      onError: (Object error) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not sync account journals: $error')),
        );
      },
    );
  }

  void _selectPage(int index) {
    setState(() {
      if (_selectedIndex == 1 && index != 1) {
        _entryToOpen = null;
        _journalResetRequest++;
      }
      _selectedIndex = index;
    });
  }

  void _openEntryFromHome(JournalEntry entry) {
    setState(() {
      _entryToOpen = entry;
      _entryOpenRequest++;
      _selectedIndex = 1;
    });
  }

  Future<void> _saveEntry(JournalEntry entry) async {
    final savedEntry = await _journalStore.saveEntry(entry);
    final updated = [
      savedEntry,
      ..._entries.where((item) => item.id != savedEntry.id),
    ];
    setState(() => _entries = updated);
  }

  Future<void> _deleteEntry(String id) async {
    await _journalStore.deleteEntry(id);
    final updated = _entries.where((item) => item.id != id).toList();
    setState(() => _entries = updated);
  }

  Future<void> _clearEntries() async {
    await _journalStore.clearEntries();
    setState(() => _entries = const []);
  }

  Future<void> _updateSettings(AppSettings settings) async {
    setState(() => _settings = settings);
    await _localStore.saveSettings(settings);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    final pages = [
      DashboardPage(
        entries: _entries,
        onStartJournal: () => _selectPage(1),
        onViewInsights: () => _selectPage(2),
        onViewReports: () => _selectPage(3),
        onViewSaved: () => _selectPage(1),
        onOpenEntry: _openEntryFromHome,
      ),
      JournalPage(
        entries: _entries,
        settings: _settings,
        entryToOpen: _entryToOpen,
        entryOpenRequest: _entryOpenRequest,
        resetRequest: _journalResetRequest,
        onEntrySaved: _saveEntry,
        onDeleteEntry: _deleteEntry,
        onViewReports: () => _selectPage(3),
      ),
      InsightsPage(entries: _entries),
      ReportsPage(entries: _entries),
      SettingsPage(
        entries: _entries,
        settings: _settings,
        darkMode: widget.darkMode,
        onThemeChanged: widget.onThemeChanged,
        onSettingsChanged: _updateSettings,
        onClearEntries: _clearEntries,
        onSignOut: widget.onSignOut,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectPage,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note),
            label: 'Journal',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.summarize_outlined),
            selectedIcon: Icon(Icons.summarize),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
