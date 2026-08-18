import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_motion.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds the app's [ThemeData] from the design tokens.
///
/// The pre-overhaul theme defined 9 component themes and no `textTheme`, which
/// is why screens re-declared `Card(color: Colors.white, shape: ...18)` 19
/// times and `Scaffold(backgroundColor: ...)` 12 times. Everything a component
/// needs is set here so screens can stop repeating it.
abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light);

  static ThemeData dark() => _build(AppColors.dark);

  static ThemeData _build(AppColors c) {
    final isDark = c.isDark;
    final textTheme = AppTypography.textTheme(c.textPrimary, c.textSecondary);

    final colorScheme = ColorScheme(
      brightness: c.brightness,
      primary: c.brand,
      onPrimary: c.onBrand,
      primaryContainer: c.brandSoft,
      onPrimaryContainer: isDark ? c.textPrimary : c.brandStrong,
      secondary: c.moduleWorkflow,
      onSecondary: c.onColor,
      secondaryContainer: c.tint(c.moduleWorkflow),
      onSecondaryContainer: c.textPrimary,
      tertiary: c.modulePaper,
      onTertiary: c.onColor,
      tertiaryContainer: c.tint(c.modulePaper),
      onTertiaryContainer: c.textPrimary,
      error: c.danger,
      onError: c.onColor,
      errorContainer: c.dangerTint,
      onErrorContainer: isDark ? c.textPrimary : c.danger,
      surface: c.surface,
      onSurface: c.textPrimary,
      surfaceContainerLowest: c.surfaceSunken,
      surfaceContainerLow: c.background,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceElevated,
      surfaceContainerHighest: c.surfaceElevated,
      onSurfaceVariant: c.textSecondary,
      outline: c.border,
      outlineVariant: c.divider,
      shadow: c.shadow,
      scrim: c.scrim,
      inverseSurface: isDark ? c.textPrimary : c.textPrimary,
      onInverseSurface: isDark ? c.background : c.surface,
      inversePrimary: c.brandSoft,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      // Ripples are the app's most common feedback; keep them soft so they read
      // as a surface response rather than a colour wash.
      splashFactory: InkSparkle.splashFactory,
      highlightColor: c.brand.withValues(alpha: 0.06),

      // One page transition on every platform. The app is primarily a web
      // build that also runs as an installed PWA on Android and iOS, so a
      // platform-conditional transition would make the same URL animate
      // differently depending on the device it was opened from.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        },
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.textPrimary,
        elevation: AppElevation.flat,
        scrolledUnderElevation: AppElevation.flat,
        // Scrolled-under tint: the neutral bar gains a hairline of separation
        // once content passes beneath it, so it reads as a layer rather than
        // floating text. Colour, not elevation - shadows are invisible on dark.
        shadowColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineSmall.copyWith(
          color: c.textPrimary,
        ),
        iconTheme: IconThemeData(color: c.textPrimary, size: AppSize.iconMd),
        actionsIconTheme:
            IconThemeData(color: c.textPrimary, size: AppSize.iconMd),
      ),

      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: c.shadow,
        elevation: AppElevation.flat,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: c.border),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.overlay,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
        titleTextStyle: AppTypography.headlineSmall.copyWith(
          color: c.textPrimary,
        ),
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: c.textSecondary,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.overlay,
        showDragHandle: true,
        dragHandleColor: c.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceSunken,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg - 2,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(color: c.textTertiary),
        labelStyle: AppTypography.bodyMedium.copyWith(color: c.textSecondary),
        floatingLabelStyle: AppTypography.labelMedium.copyWith(color: c.brand),
        helperStyle: AppTypography.bodySmall.copyWith(color: c.textSecondary),
        errorStyle: AppTypography.bodySmall.copyWith(color: c.danger),
        prefixIconColor: c.textSecondary,
        suffixIconColor: c.textSecondary,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: c.brand, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: c.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: c.danger, width: 2),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: c.onBrand,
          disabledBackgroundColor: c.border,
          disabledForegroundColor: c.textTertiary,
          textStyle: AppTypography.labelLarge,
          minimumSize: const Size(0, AppSize.tapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: AppRadius.mdShape,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: c.onBrand,
          disabledBackgroundColor: c.border,
          disabledForegroundColor: c.textTertiary,
          shadowColor: c.shadow,
          elevation: AppElevation.raised,
          textStyle: AppTypography.labelLarge,
          minimumSize: const Size(0, AppSize.tapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: AppRadius.mdShape,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.brand,
          disabledForegroundColor: c.textTertiary,
          side: BorderSide(color: c.brand.withValues(alpha: 0.5)),
          textStyle: AppTypography.labelLarge,
          minimumSize: const Size(0, AppSize.tapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: AppRadius.mdShape,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.brand,
          disabledForegroundColor: c.textTertiary,
          textStyle: AppTypography.labelLarge,
          minimumSize: const Size(0, AppSize.tapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: AppRadius.mdShape,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.textSecondary,
          minimumSize: const Size(AppSize.tapTarget, AppSize.tapTarget),
        ),
      ),

      iconTheme: IconThemeData(color: c.textSecondary, size: AppSize.iconMd),

      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceSunken,
        selectedColor: c.brandSoft,
        disabledColor: c.surfaceSunken,
        checkmarkColor: c.brand,
        labelStyle: AppTypography.labelMedium.copyWith(color: c.textPrimary),
        secondaryLabelStyle:
            AppTypography.labelMedium.copyWith(color: c.brand),
        side: BorderSide(color: c.border),
        shape: AppRadius.pillShape,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: c.divider,
        thickness: 1,
        space: AppSpacing.xl,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
        titleTextStyle: AppTypography.titleMedium.copyWith(
          color: c.textPrimary,
        ),
        subtitleTextStyle: AppTypography.bodySmall.copyWith(
          color: c.textSecondary,
        ),
        shape: AppRadius.mdShape,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
      ),

      expansionTileTheme: ExpansionTileThemeData(
        // ExpansionTile draws its own dividers, which fight the card border.
        // Four screens each patched this with a copy-pasted
        // `Theme(dividerColor: transparent)` wrapper; setting it here removes
        // the need for all of them.
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        iconColor: c.brand,
        collapsedIconColor: c.textSecondary,
        textColor: c.textPrimary,
        collapsedTextColor: c.textPrimary,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        collapsedShape:
            const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.brand,
        linearTrackColor: c.surfaceSunken,
        circularTrackColor: c.surfaceSunken,
        linearMinHeight: AppSpacing.sm,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? c.surfaceElevated : c.textPrimary,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: isDark ? c.textPrimary : c.surface,
        ),
        actionTextColor: isDark ? c.brand : c.premium,
        elevation: AppElevation.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? c.surfaceElevated : c.textPrimary,
          borderRadius: AppRadius.smAll,
          border: isDark ? Border.all(color: c.border) : null,
        ),
        textStyle: AppTypography.labelSmall.copyWith(
          color: isDark ? c.textPrimary : c.surface,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        waitDuration: AppMotion.slow,
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.brand;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll<Color>(c.onBrand),
        side: BorderSide(color: c.border, width: 1.5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(5)),
        ),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.brand;
          return c.border;
        }),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.onBrand;
          return c.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.brand;
          return c.surfaceSunken;
        }),
        trackOutlineColor: WidgetStatePropertyAll<Color>(c.border),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: c.brand,
        inactiveTrackColor: c.surfaceSunken,
        thumbColor: c.brand,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.brandSoft,
        indicatorShape: AppRadius.pillShape,
        elevation: AppElevation.floating,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTypography.labelSmall.copyWith(
            color: selected ? c.brand : c.textSecondary,
            fontWeight:
                selected ? AppTypography.semiBold : AppTypography.medium,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? c.brand : c.textSecondary,
            size: AppSize.iconMd,
          );
        }),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.brandSoft,
        indicatorShape: AppRadius.mdShape,
        elevation: AppElevation.flat,
        useIndicator: true,
        selectedIconTheme:
            IconThemeData(color: c.brand, size: AppSize.iconMd),
        unselectedIconTheme:
            IconThemeData(color: c.textSecondary, size: AppSize.iconMd),
        selectedLabelTextStyle: AppTypography.labelMedium.copyWith(
          color: c.brand,
          fontWeight: AppTypography.semiBold,
        ),
        unselectedLabelTextStyle:
            AppTypography.labelMedium.copyWith(color: c.textSecondary),
      ),

      drawerTheme: DrawerThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.overlay,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            right: Radius.circular(AppRadius.xl),
          ),
        ),
      ),

      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll<Color>(c.surfaceSunken),
        headingTextStyle: AppTypography.labelMedium.copyWith(
          color: c.textSecondary,
        ),
        dataTextStyle: AppTypography.bodySmall.copyWith(color: c.textPrimary),
        dividerThickness: 1,
        horizontalMargin: AppSpacing.lg,
        columnSpacing: AppSpacing.xl,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: c.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        textStyle: AppTypography.bodyMedium.copyWith(color: c.textPrimary),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: c.surface,
          foregroundColor: c.textSecondary,
          selectedBackgroundColor: c.brandSoft,
          selectedForegroundColor: c.brand,
          side: BorderSide(color: c.border),
          textStyle: AppTypography.labelMedium,
          shape: AppRadius.mdShape,
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: c.brand,
        unselectedLabelColor: c.textSecondary,
        labelStyle: AppTypography.labelLarge,
        unselectedLabelStyle: AppTypography.labelLarge,
        indicatorColor: c.brand,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: c.divider,
      ),
    );
  }
}
