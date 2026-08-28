import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: child));
  }
}

class WellnessCard extends StatelessWidget {
  const WellnessCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: padding, child: child),
    );
  }
}

class IconBox extends StatelessWidget {
  const IconBox({super.key, required this.icon, this.color, this.size = 44});

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: accent, size: size * 0.5),
    );
  }
}

class PageTitle extends StatelessWidget {
  const PageTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          ?action,
        ],
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    required this.label,
    required this.hint,
    this.icon,
    this.maxLines = 1,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
    this.suffixIcon,
  });

  final TextEditingController? controller;
  final String label;
  final String hint;
  final IconData? icon;
  final int maxLines;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final FormFieldValidator<String>? validator;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class MoodBadge extends StatelessWidget {
  const MoodBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.18),
      side: BorderSide(color: color.withValues(alpha: 0.36)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.self_improvement,
        size: size * 0.56,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class AuthFormShell extends StatelessWidget {
  const AuthFormShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.children,
  });

  final String title;
  final String subtitle;
  final Widget leading;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Align(alignment: Alignment.centerLeft, child: leading),
          const SizedBox(height: 20),
          const BrandMark(size: 56),
          const SizedBox(height: 24),
          Text(title, style: theme.textTheme.displayLarge),
          const SizedBox(height: 8),
          Text(subtitle, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 28),
          ...children,
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: WellnessCard(
          child: Row(
            children: [
              IconBox(icon: icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(label, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScrollToTopOverlay extends StatefulWidget {
  const ScrollToTopOverlay({super.key, required this.builder});

  final Widget Function(ScrollController controller) builder;

  @override
  State<ScrollToTopOverlay> createState() => _ScrollToTopOverlayState();
}

class _ScrollToTopOverlayState extends State<ScrollToTopOverlay> {
  final ScrollController _controller = ScrollController();
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    final nextVisible = _controller.hasClients && _controller.offset > 280;
    if (nextVisible != _visible && mounted) {
      setState(() => _visible = nextVisible);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.builder(_controller),
        Positioned(
          right: 18,
          bottom: 18,
          child: IgnorePointer(
            ignoring: !_visible,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _visible ? 1 : 0,
              child: FloatingActionButton.small(
                heroTag: null,
                tooltip: 'Back to top',
                onPressed: () {
                  _controller.animateTo(
                    0,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                  );
                },
                child: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
