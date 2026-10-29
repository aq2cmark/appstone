import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// A compact reminder that AI output is informational and needs human review.
class AiDisclaimer extends StatelessWidget {
  const AiDisclaimer({super.key, this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Text(
      text ??
          'AI-generated guidance may be inaccurate. Review it carefully; it '
          'is not professional advice or a substitute for your adviser or '
          'capstone panel.',
      style: AppTypography.bodySmall.copyWith(color: colors.textTertiary),
    );
  }
}
