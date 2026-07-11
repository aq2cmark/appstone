import 'package:appstone/app_colors.dart';
import 'package:appstone/firebase_options.dart';
import 'package:appstone/screens/auth_gate.dart';
import 'package:appstone/screens/capstone_manual_screen.dart';
import 'package:appstone/screens/defense_practice_screen.dart';
import 'package:appstone/screens/session_history_screen.dart';
import 'package:appstone/screens/title_defense_screen.dart';
import 'package:appstone/screens/title_generator_screen.dart';
import 'package:appstone/screens/ai_workflow_screen.dart';
import 'package:appstone/screens/paper_checker_screen.dart';
import 'package:appstone/widgets/auth_guard.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

// App entry point.
// Firebase must be initialized before any screen reads Auth or Firestore.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MainApp());
}

// MainApp keeps global app settings in one place:
// theme colors, the first screen, and named routes for feature pages.
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AppStone',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
        // One shared card look for the whole app: any Card() that doesn't
        // override color/shape gets this, so admin and student screens
        // that forgot to set it still match everywhere else.
        cardTheme: const CardThemeData(
          color: AppColors.white,
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        // One consistent, branded look for every dialog, text field, and button
        // so the popups (forgot password, create group, invite admin, edit
        // student, confirmations, etc.) all match the app instead of falling
        // back to default Material styling.
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.white,
          surfaceTintColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
          contentTextStyle: const TextStyle(
            fontSize: 14.5,
            color: AppColors.textDark,
            height: 1.4,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.background,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
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
        '/title-defense': (_) => const PremiumGuard(child: TitleDefenseScreen()),
        '/oral-defense': (_) => const PremiumGuard(child: OralDefenseScreen()),
        '/final-defense': (_) => const PremiumGuard(child: FinalDefenseScreen()),
        '/session-history': (_) =>
            const PremiumGuard(child: SessionHistoryScreen()),
        '/ai-workflow': (_) => const PremiumGuard(child: AIWorkflowScreen()),
        '/paper-checker': (_) => const PremiumGuard(child: PaperCheckerScreen()),
      },
    );
  }
}
