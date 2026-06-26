import 'package:appstone/firebase_options.dart';
import 'package:appstone/screens/capstone_manual_screen.dart';
import 'package:appstone/screens/defense_practice_screen.dart';
import 'package:appstone/screens/login_page.dart';
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF9E1B1F)),
        scaffoldBackgroundColor: const Color(0xFFF3F1EF),
        useMaterial3: true,
      ),
      home: const LoginPage(),
      // Named routes let dashboard cards open screens by route name.
      // Add future feature pages here when your group creates new screens.
      routes: {
        '/capstone-manual': (_) => const CapstoneManualScreen(),
        '/title-generator': (_) => const TitleGeneratorScreen(),
        '/defense-practice': (_) => const DefensePracticeScreen(),
        '/title-defense': (_) => const TitleDefenseScreen(),
        '/ai-workflow': (_) => const AIWorkflowScreen(),
        '/paper-checker': (_) => const PaperCheckerScreen(),
      },
    );
  }
}
