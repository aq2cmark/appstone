import 'package:appstone/firebase_options.dart';
import 'package:appstone/screens/auth_gate.dart';
import 'package:appstone/screens/capstone_manual_screen.dart';
import 'package:appstone/screens/defense_context_screen.dart';
import 'package:appstone/screens/defense_practice_screen.dart';
import 'package:appstone/screens/session_history_screen.dart';
import 'package:appstone/screens/title_defense_screen.dart';
import 'package:appstone/screens/title_generator_screen.dart';
import 'package:appstone/screens/ai_workflow_screen.dart';
import 'package:appstone/screens/paper_checker_screen.dart';
import 'package:appstone/screens/paper_check_history_screen.dart';
import 'package:appstone/theme/app_motion.dart';
import 'package:appstone/theme/app_theme.dart';
import 'package:appstone/theme/theme_controller.dart';
import 'package:appstone/widgets/auth_guard.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

// App entry point.
// Firebase must be initialized before any screen reads Auth or Firestore.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Read the saved light/dark preference before the first frame, so the app
  // never flashes the wrong background on startup.
  await ThemeController.instance.load();
  runApp(const MainApp());
}

// MainApp keeps global app settings in one place:
// theme colors, the first screen, and named routes for feature pages.
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    // The whole app rebuilds when the theme preference changes; nothing else
    // has to listen. See lib/theme/theme_controller.dart.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, themeMode, _) => _buildApp(themeMode),
    );
  }

  Widget _buildApp(ThemeMode themeMode) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Appstone',
      // All design tokens live in lib/theme/. Screens must not define colours,
      // type, spacing or radii of their own - see CLAUDE.md.
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      // Browser and OS accessibility settings can push text scale past 2x,
      // which overflowed several fixed-height layouts. Clamping keeps the app
      // legible and usable for readers who need larger type without letting a
      // 3x setting shred the layout.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.6,
            ),
          ),
          // Toggling light/dark swaps every colour in the app at once. Without
          // this the switch lands as a hard flash, which is unpleasant at
          // night - and the toggle now sits in every app bar, so it is the
          // control people trigger most.
          child: AnimatedTheme(
            data: Theme.of(context),
            duration: AppMotion.respect(context, AppMotion.slow),
            curve: AppMotion.standardCurve,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const AuthGate(),
      // Named routes let dashboard cards open screens by route name.
      // Add future feature pages here when your group creates new screens.
      // Every feature route is wrapped in AuthGuard so it can't be opened by
      // typing the URL (e.g. /#/title-generator) without being signed in.
      // Free features only need a login (AuthGuard); premium features also
      // require the student's group to be premium (PremiumGuard) so a direct
      // URL can't bypass the paywall.
      routes: {
        '/capstone-manual': (_) =>
            const AuthGuard(child: CapstoneManualScreen()),
        '/title-generator': (_) =>
            const AuthGuard(child: TitleGeneratorScreen()),
        '/defense-practice': (_) =>
            const PremiumGuard(child: DefensePracticeScreen()),
        '/defense-context': (_) =>
            const PremiumGuard(child: DefenseContextScreen()),
        '/title-defense': (_) => const PremiumGuard(child: TitleDefenseScreen()),
        '/oral-defense': (_) => const PremiumGuard(child: OralDefenseScreen()),
        '/final-defense': (_) => const PremiumGuard(child: FinalDefenseScreen()),
        '/session-history': (_) =>
            const PremiumGuard(child: SessionHistoryScreen()),
        '/ai-workflow': (_) => const PremiumGuard(child: AIWorkflowScreen()),
        '/paper-checker': (_) => const PremiumGuard(child: PaperCheckerScreen()),
        '/paper-check-history': (_) =>
            const PremiumGuard(child: PaperCheckHistoryScreen()),
      },
    );
  }
}
