import 'package:flutter/material.dart';

import '../models/models.dart';
import '../widgets/common_widgets.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({
    super.key,
    required this.darkMode,
    required this.onThemeChanged,
    required this.onLogin,
    required this.onCreateAccount,
  });

  final bool darkMode;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onLogin;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Row(
            children: [
              const BrandMark(size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Text('MindSet', style: theme.textTheme.headlineMedium),
              ),
              IconButton.filledTonal(
                tooltip: darkMode ? 'Light theme' : 'Dark theme',
                onPressed: () => onThemeChanged(!darkMode),
                icon: Icon(darkMode ? Icons.light_mode : Icons.dark_mode),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Understand your feelings without overthinking them.',
            style: theme.textTheme.displayLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Record your reflections, receive simple emotion labels, and notice gentle patterns.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          _FeatureGrid(
            items: const [
              FeatureItem(
                icon: Icons.edit_note,
                title: 'Text journal',
                subtitle: 'Capture raw feelings and turn them into labels.',
              ),
              FeatureItem(
                icon: Icons.keyboard_voice,
                title: 'Voice notes',
                subtitle: 'Keep reflections natural when typing feels heavy.',
              ),
              FeatureItem(
                icon: Icons.insights,
                title: 'Patterns',
                subtitle: 'Review recurring moods, triggers, and supports.',
              ),
              FeatureItem(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy',
                subtitle: 'Keep behaviour signals separate from content.',
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreateAccount,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Create account'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onLogin,
            icon: const Icon(Icons.login),
            label: const Text('Log in'),
          ),
        ],
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.items});

  final List<FeatureItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 620 ? 2 : 1;
        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: columns == 1 ? 3.9 : 2.8,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return WellnessCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBox(icon: item.icon, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
