import 'package:flutter/material.dart';

import '../app_colors.dart';

// Shared page-header banner. Used by both the Admin Portal and the Student
// Dashboard so the two main "hub" screens look like one app instead of two:
// same background, padding, and title/subtitle/chip styling everywhere.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.chips = const [],
    this.leading,
    this.actions = const [],
    this.maxContentWidth,
  });

  final String title;
  final String? subtitle;
  // Small pill badges shown under the title (e.g. group name, premium status).
  final List<String> chips;
  final Widget? leading;
  final List<Widget> actions;
  // Centers and caps the header content to match a constrained body below it.
  final double? maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...actions,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, style: const TextStyle(color: Colors.white)),
        ],
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final chip in chips) HeaderPill(chip)],
          ),
        ],
      ],
    );

    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: SafeArea(
        bottom: false,
        child: maxContentWidth == null
            ? content
            : Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth!),
                  child: content,
                ),
              ),
      ),
    );
  }
}

class HeaderPill extends StatelessWidget {
  const HeaderPill(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}
