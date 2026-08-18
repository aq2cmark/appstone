import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Solid rounded icon tile. Shared by the student home's feature cards and the
/// admin portal's stat cards so both hubs use the same icon language.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = AppSize.tileSm,
    this.soft = false,
  });

  final IconData icon;
  final Color color;
  final double size;

  /// Renders as a tinted wash with a coloured glyph instead of a solid fill.
  /// Softer, and it keeps long screens from turning into a field of colour
  /// blocks.
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: soft ? colors.tint(color) : color,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        icon,
        color: soft ? color : colors.onColor,
        size: size * 0.5,
      ),
    );
  }
}

/// One tappable feature card on the student home.
///
/// The previous version wrapped its content in a hard `height: 272` box, which
/// overflowed once the title wrapped to a second line or the reader raised
/// their text scale. It now sizes to its content with a minimum height, and
/// both text runs are bounded, so it cannot overflow at any width or scale.
class AppFeatureCard extends StatelessWidget {
  const AppFeatureCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
    this.locked = false,
    this.minHeight = 168,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  /// The module accent. Drives the icon tile, the hover glow, and the corner
  /// wash, so each feature is identifiable before the label is read.
  final Color color;

  final VoidCallback? onTap;
  final bool locked;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return _HoverLift(
      color: color,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Stack(
          children: <Widget>[
            // A soft corner wash in the module colour. Cheap, and it stops a
            // grid of five cards from reading as five identical white boxes.
            Positioned(
              right: -34,
              top: -34,
              child: Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: colors.isDark ? 0.14 : 0.07),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      IconBadge(icon: icon, color: color, size: AppSize.tileLg),
                      const Spacer(),
                      if (locked)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.tint(colors.premium),
                            borderRadius: AppRadius.pillAll,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.lock_rounded,
                                size: 12,
                                color: colors.premium,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Premium',
                                style: AppTypography.labelSmall.copyWith(
                                  color: colors.premium,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  AppSpacing.vLg,
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleLarge.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  AppSpacing.vXs,
                  Text(
                    subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A card that lifts and glows in its accent colour while hovered.
///
/// The pre-overhaul dashboard did this with a "dock" that magnified the
/// hovered card and shrank its neighbours - good-looking, but it only worked
/// when every card fit on one row and it required the fixed card height that
/// caused the overflow above. This keeps the feel at every width.
class _HoverLift extends StatefulWidget {
  const _HoverLift({
    required this.child,
    required this.color,
    this.onTap,
  });

  final Widget child;
  final Color color;
  final VoidCallback? onTap;

  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<_HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppMotion.respect(context, AppMotion.quick),
        curve: AppMotion.enter,
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: AppRadius.lgAll,
          boxShadow: _hovered
              ? <BoxShadow>[
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.28),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: Material(
          color: colors.surface,
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.lgAll,
            side: BorderSide(
              color: _hovered ? widget.color.withValues(alpha: 0.5)
                  : colors.border,
            ),
          ),
          child: InkWell(
            onTap: widget.onTap,
            splashColor: widget.color.withValues(alpha: 0.10),
            highlightColor: widget.color.withValues(alpha: 0.06),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
