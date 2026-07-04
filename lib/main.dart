import 'package:appstone/app_colors.dart';
import 'package:appstone/firebase_options.dart';
import 'package:appstone/screens/auth_gate.dart';
import 'package:appstone/screens/capstone_manual_screen.dart';
import 'package:appstone/screens/defense_practice_screen.dart';
import 'package:appstone/screens/title_defense_screen.dart';
import 'package:appstone/screens/title_generator_screen.dart';
import 'package:appstone/screens/ai_workflow_screen.dart';
import 'package:appstone/screens/paper_checker_screen.dart';
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
      ),
      home: const AuthGate(),
      // Named routes let dashboard cards open screens by route name.
      // Add future feature pages here when your group creates new screens.
      routes: {
        '/capstone-manual': (_) => const CapstoneManualScreen(),
        '/title-generator': (_) => const TitleGeneratorScreen(),
        '/defense-practice': (_) => const DefensePracticeScreen(),
        '/title-defense': (_) => const TitleDefenseScreen(),
        '/oral-defense': (_) => const OralDefenseScreen(),
        '/final-defense': (_) => const FinalDefenseScreen(),
        '/ai-workflow': (_) => const AIWorkflowScreen(),
        '/paper-checker': (_) => const PaperCheckerScreen(),
      },
    );
  }
}
