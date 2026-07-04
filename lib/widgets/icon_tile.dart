import 'package:flutter/material.dart';

import '../app_colors.dart';

// Solid-color rounded icon square. Shared by the student dashboard's feature
// cards and the admin dashboard's stat cards so both "hub" screens use the
// same icon language instead of two different implementations.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 56,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

// One tappable feature card: icon, title, and a short description. The parent
// grid computes [width] from a column count, so the same card design fills the
// row on a wide desktop and reflows into fewer columns on a phone - no separate
// mobile layout.
class AppFeatureCard extends StatelessWidget {
  const AppFeatureCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.width,
    this.onTap,
    this.locked = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double width;
  final VoidCallback? onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 200,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconBadge(icon: icon, color: color, size: 64),
                    const Spacer(),
                    if (locked)
                      const Icon(
                        Icons.lock_outline,
                        size: 22,
                        color: AppColors.gold,
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
