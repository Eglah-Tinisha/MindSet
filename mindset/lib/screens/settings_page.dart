import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/journal_analytics.dart';
import '../widgets/common_widgets.dart';
import '../widgets/settings_widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.entries,
    required this.settings,
    required this.darkMode,
    required this.onThemeChanged,
    required this.onSettingsChanged,
    required this.onClearEntries,
    required this.onSignOut,
  });

  final List<JournalEntry> entries;
  final AppSettings settings;
  final bool darkMode;
  final ValueChanged<bool> onThemeChanged;
  final ValueChanged<AppSettings> onSettingsChanged;
  final Future<void> Function() onClearEntries;
  final VoidCallback onSignOut;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _endpointController;

  @override
  void initState() {
    super.initState();
    _endpointController = TextEditingController(
      text: widget.settings.apiEndpoint,
    );
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settings.apiEndpoint != oldWidget.settings.apiEndpoint &&
        _endpointController.text != widget.settings.apiEndpoint) {
      _endpointController.text = widget.settings.apiEndpoint;
    }
  }

  @override
  void dispose() {
    _endpointController.dispose();
    super.dispose();
  }

  void _update(AppSettings settings) {
    widget.onSettingsChanged(settings);
  }

  Future<void> _confirmClearEntries() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear account journals?'),
          content: Text(
            'This removes ${widget.entries.length} saved ${widget.entries.length == 1 ? 'entry' : 'entries'} from this Firebase account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await widget.onClearEntries();
      } catch (error) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not clear account journals: $error')),
        );
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account journals cleared.')),
        );
      }
    }
  }

  Future<void> _showProfileDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No signed-in profile found.')),
      );
      return;
    }

    final analytics = JournalAnalytics(widget.entries);
    final createdAt = _formatProfileDate(user.metadata.creationTime);
    final lastSignIn = _formatProfileDate(user.metadata.lastSignInTime);

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.account_circle_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('Profile')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ProfileDetailRow(
                  icon: Icons.badge_outlined,
                  label: 'Name',
                  value: _profileName(user),
                ),
                _ProfileDetailRow(
                  icon: Icons.mail_outline,
                  label: 'Email',
                  value: user.email ?? 'No email',
                ),
                _ProfileDetailRow(
                  icon: Icons.article_outlined,
                  label: 'Saved reflections',
                  value: '${widget.entries.length}',
                ),
                _ProfileDetailRow(
                  icon: Icons.local_fire_department_outlined,
                  label: 'Current streak',
                  value:
                      '${analytics.currentStreak} ${analytics.currentStreak == 1 ? 'day' : 'days'}',
                ),
                _ProfileDetailRow(
                  icon: Icons.event_available_outlined,
                  label: 'Created',
                  value: createdAt,
                ),
                _ProfileDetailRow(
                  icon: Icons.login_outlined,
                  label: 'Last sign-in',
                  value: lastSignIn,
                ),
                _ProfileDetailRow(
                  icon: Icons.fingerprint,
                  label: 'User ID',
                  value: user.uid,
                  selectable: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScrollToTopOverlay(
      builder: (scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: PageTitle(
                  title: 'Settings',
                  subtitle: 'Keep the app calm, private, and useful.',
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Profile',
                onPressed: _showProfileDetails,
                icon: const Icon(Icons.account_circle_outlined),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SettingsSwitchTile(
            icon: widget.darkMode ? Icons.dark_mode : Icons.light_mode,
            title: 'Dark mode',
            subtitle: 'Use the gentler dark interface.',
            value: widget.darkMode,
            onChanged: widget.onThemeChanged,
          ),
          const SizedBox(height: 12),
          SettingsSwitchTile(
            icon: Icons.keyboard_voice_outlined,
            title: 'Voice reflections',
            subtitle: 'Allow voice notes for journal entries.',
            value: widget.settings.voiceReflection,
            onChanged: (value) =>
                _update(widget.settings.copyWith(voiceReflection: value)),
          ),
          const SizedBox(height: 12),
          SettingsSwitchTile(
            icon: Icons.bookmark_add_outlined,
            title: 'Auto-save analysis',
            subtitle: 'Save each successful AI result automatically.',
            value: widget.settings.autoSaveEntries,
            onChanged: (value) =>
                _update(widget.settings.copyWith(autoSaveEntries: value)),
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Local AI Endpoint'),
          WellnessCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _endpointController,
                  label: 'Text analyze URL',
                  hint: 'http://10.0.2.2:8000/predict',
                  icon: Icons.api_outlined,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    final endpoint = _endpointController.text.trim();
                    final uri = Uri.tryParse(endpoint);
                    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a valid local API URL.'),
                        ),
                      );
                      return;
                    }
                    _update(widget.settings.copyWith(apiEndpoint: endpoint));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('API endpoint saved.')),
                    );
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save endpoint'),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Optional Signals'),
          SettingsSwitchTile(
            icon: Icons.keyboard_alt_outlined,
            title: 'Typing pattern insights',
            subtitle:
                'Optionally analyze typing behaviour for text journals.',
            value: widget.settings.typingRhythm,
            onChanged: (value) =>
                _update(widget.settings.copyWith(typingRhythm: value)),
          ),
          const SizedBox(height: 12),
          const PrivacyNotice(
            icon: Icons.privacy_tip_outlined,
            title: 'Private aggregate behaviour only',
            text:
                'When enabled, MindSet stores only typing metrics and results with a saved journal.',
          ),
          const SizedBox(height: 18),
          const PrivacyNotice(
            icon: Icons.privacy_tip_outlined,
            title: 'You control what is analyzed',
            text:
                'Your toggles and API endpoint stay on this device, journals on your signed-in Firebase account.',
          ),
          const SizedBox(height: 18),
          SettingsActionTile(
            icon: Icons.delete_outline,
            title: 'Clear account journals',
            subtitle:
                '${widget.entries.length} saved ${widget.entries.length == 1 ? 'entry' : 'entries'} in this account.',
            trailing: const Icon(Icons.chevron_right),
            onTap: widget.entries.isEmpty ? null : _confirmClearEntries,
          ),
          const SizedBox(height: 12),
          SettingsActionTile(
            icon: Icons.logout,
            title: 'Sign out',
            subtitle: 'Return to the welcome screen.',
            trailing: const Icon(Icons.chevron_right),
            onTap: widget.onSignOut,
          ),
        ],
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelMedium),
                const SizedBox(height: 2),
                selectable
                    ? SelectableText(value, style: theme.textTheme.bodyMedium)
                    : Text(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _profileName(User user) {
  final displayName = user.displayName?.trim();
  if (displayName != null && displayName.isNotEmpty) {
    return displayName;
  }
  final email = user.email ?? '';
  if (email.contains('@')) {
    return email.split('@').first;
  }
  return 'MindSet User';
}

String _formatProfileDate(DateTime? value) {
  if (value == null) {
    return 'Not available';
  }

  final local = value.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}
