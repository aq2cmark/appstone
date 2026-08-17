import 'package:flutter/material.dart';

import '../theme/app_breakpoints.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The page chassis every screen uses.
///
/// Replaces two duplicated patterns: 13 hand-built [AppBar]s that each
/// re-specified their own colours, and the
/// `ListView > Center > ConstrainedBox(maxWidth: 760)` idiom that was
/// copy-pasted into nine student screens with no shared constant.
///
/// It owns page padding, the content measure, safe areas, and the accent hair
/// line that tells the user which module they are in.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const <Widget>[],
    this.leading,
    this.accent,
    this.maxContentWidth = AppContentWidth.reading,
    this.scrollable = true,
    this.padded = true,
    this.bottomBar,
    this.floatingActionButton,
    this.automaticallyImplyLeading = true,
  });

  final String title;

  /// Sits under the title in the app bar. Kept short - it is not a paragraph.
  final String? subtitle;

  final Widget body;
  final List<Widget> actions;
  final Widget? leading;

  /// The module accent (see [AppColors.moduleFor]). Draws a hair line under
  /// the app bar so each module is identifiable at a glance.
  final Color? accent;

  /// Content measure. Use [AppContentWidth.form] for forms,
  /// [AppContentWidth.reading] for a single column, [AppContentWidth.wide] for
  /// two-column desktop layouts, [AppContentWidth.max] for tables and grids.
  final double maxContentWidth;

  /// When false, [body] is placed directly and is responsible for its own
  /// scrolling - required for screens that host a `ListView.builder`, a
  /// `TabBarView`, or a two-pane layout with independently scrolling sides.
  final bool scrollable;

  /// Applies the standard responsive page padding.
  final bool padded;

  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tone = accent ?? colors.brand;
    final pad = padded ? context.pagePadding : 0.0;

    Widget content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: body,
      ),
    );

    if (scrollable) {
      content = SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + AppSpacing.xxl),
        child: content,
      );
    } else if (padded) {
      content = Padding(padding: EdgeInsets.all(pad), child: content);
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        titleSpacing: leading == null && !automaticallyImplyLeading
            ? context.pagePadding
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.headlineSmall.copyWith(
                color: colors.textPrimary,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
          ],
        ),
        actions: <Widget>[
          ...actions,
          SizedBox(width: context.pagePadding - AppSpacing.sm),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: tone.withValues(alpha: 0.85)),
        ),
      ),
      body: SafeArea(top: false, child: content),
      bottomNavigationBar: bottomBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

/// A labelled block within a page.
///
/// Renders the small uppercase marker the app already used inline on three
/// screens ("EXPLORE FEATURES", "CONTENTS", "N RESULTS"), plus an optional
/// trailing action.
class AppSection extends StatelessWidget {
  const AppSection({
    super.key,
    required this.label,
    required this.child,
    this.trailing,
    this.accent,
  });

  final String label;
  final Widget child;
  final Widget? trailing;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.eyebrow.copyWith(
                  color: accent ?? colors.textTertiary,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        AppSpacing.vMd,
        child,
      ],
    );
  }
}

/// Splits a screen into a main column and a side column on wide windows, and
/// stacks them on narrow ones.
///
/// This is what turns the Paper Checker, AI Workflow and defense session
/// screens from a 760 px strip on a 1920 px monitor into a real desktop layout.
/// The decision is made from the width actually available, not the window, so
/// it stays correct when the navigation rail is taking 250 px.
class AppTwoColumn extends StatelessWidget {
  const AppTwoColumn({
    super.key,
    required this.main,
    required this.side,
    this.sideWidth = 380,
    this.gap = AppSpacing.xl,
    this.sideFirstWhenStacked = false,
  });

  final Widget main;
  final Widget side;
  final double sideWidth;
  final double gap;

  /// When stacked, put the side column above the main one - used where the
  /// side content is a summary that should lead on a phone.
  final bool sideFirstWhenStacked;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            AppBreakpoints.fromWidth(constraints.maxWidth).usesTwoColumn;

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: sideFirstWhenStacked
                ? <Widget>[side, SizedBox(height: gap), main]
                : <Widget>[main, SizedBox(height: gap), side],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: main),
            SizedBox(width: gap),
            SizedBox(width: sideWidth, child: side),
          ],
        );
      },
    );
  }
}
