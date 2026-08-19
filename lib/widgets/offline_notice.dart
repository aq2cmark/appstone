import 'dart:async';

import 'package:flutter/material.dart';

import '../services/connectivity.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Rebuilds [builder] whenever the device goes on or offline.
///
/// Each instance owns its own subscription rather than reading a shared
/// notifier, so this adds no global state - see CLAUDE.md.
class OnlineStatusBuilder extends StatefulWidget {
  const OnlineStatusBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, bool online) builder;

  @override
  State<OnlineStatusBuilder> createState() => _OnlineStatusBuilderState();
}

class _OnlineStatusBuilderState extends State<OnlineStatusBuilder> {
  late bool _online = isOnline;
  StreamSubscription<bool>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = onlineChanges.listen((online) {
      if (mounted && online != _online) setState(() => _online = online);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _online);
}

/// An advisory strip shown only while the device is offline.
///
/// It states what still works rather than only what does not: the Capstone
/// Manual ships inside the app bundle, so it is readable with no connection,
/// and a student who has lost signal should be told that instead of being left
/// to guess from a failed request.
///
/// Renders nothing at all when online, and it never blocks anything - the
/// screen below stays fully interactive.
class OfflineNotice extends StatelessWidget {
  const OfflineNotice({super.key, required this.message});

  /// What the student can still do from this screen.
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return OnlineStatusBuilder(
      builder: (context, online) => AnimatedSize(
        duration: AppMotion.respect(context, AppMotion.standard),
        curve: AppMotion.enter,
        alignment: Alignment.topCenter,
        child: online
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.warningTint,
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(color: colors.tintBorder(colors.warning)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.wifi_off_rounded,
                        size: AppSize.iconSm,
                        color: colors.warning,
                      ),
                      AppSpacing.hMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              "You're offline",
                              style: AppTypography.labelLarge.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            AppSpacing.vXs,
                            Text(
                              message,
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
              ),
      ),
    );
  }
}
