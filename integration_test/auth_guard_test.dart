// Real integration test of the route guards against a REAL Firebase Auth +
// Firestore backend - the local emulator suite, never production. This is
// the coverage the unit/widget suite is missing: AuthGuard, PremiumGuard and
// the owner-only sidebar in AdminPortalPage all call `FirebaseAuth.instance`
// / `FirebaseFirestore.instance` directly (not injected), so they can only be
// exercised against a real Firebase App - either the emulator (here) or
// production (never, in a test). Cloud Functions (createStudent, inviteAdmin,
// etc.) are intentionally NOT covered here - see the report for why.
//
// Test data for `groups` / `studentIndex` / `admins` is seeded through the
// emulator's REST API with the special `Authorization: Bearer owner` token,
// which bypasses firestore.rules. That's deliberate, not a shortcut: in the
// real app those collections are written only by Cloud Functions (Admin SDK,
// which also bypasses rules) - a plain signed-in client was never able to
// write them, and firestore.rules correctly rejects it here too (confirmed by
// this test's first draft, which tried exactly that and got
// permission-denied). Seeding has to go around the same wall the app does.
//
// Prerequisite (must already be running):
//   firebase emulators:start --only auth,firestore --project appstone-db
//
// Run with (via test_driver, since `flutter test -d chrome` doesn't support
// web devices for integration_test yet):
//   flutter drive --driver=test_driver/integration_test.dart --target=integration_test/auth_guard_test.dart -d chrome --browser-name=chrome
//   flutter drive --driver=test_driver/integration_test.dart --target=integration_test/auth_guard_test.dart -d edge --browser-name=edge
import 'dart:convert';

import 'package:appstone/firebase_options.dart';
import 'package:appstone/screens/admin_portal_page.dart';
import 'package:appstone/services/admin_repository.dart';
import 'package:appstone/widgets/auth_guard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

const _projectId = 'appstone-db';
const _firestoreEmulatorBase =
    'http://127.0.0.1:8080/v1/projects/$_projectId/databases/(default)/documents';

Future<void> _pointAtEmulators() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
}

// Firestore REST "value" encoding for the handful of scalar types this file
// needs. Not a general-purpose converter - just enough for test fixtures.
Map<String, dynamic> _value(dynamic v) {
  if (v is String) return {'stringValue': v};
  if (v is bool) return {'booleanValue': v};
  if (v is List) {
    return {
      'arrayValue': {'values': v.map(_value).toList()},
    };
  }
  if (v is DateTime) return {'timestampValue': v.toUtc().toIso8601String()};
  throw ArgumentError('Unsupported fixture value type: ${v.runtimeType}');
}

// Upserts a document at an EXPLICIT path directly against the emulator,
// bypassing firestore.rules via the `owner` bearer token. Used only to set up
// fixtures the real app would otherwise create through Cloud Functions.
Future<void> _seed(String documentPath, Map<String, dynamic> data) async {
  final fields = {for (final e in data.entries) e.key: _value(e.value)};
  final response = await http.patch(
    Uri.parse('$_firestoreEmulatorBase/$documentPath'),
    headers: {
      'Authorization': 'Bearer owner',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'fields': fields}),
  );
  if (response.statusCode >= 300) {
    throw StateError(
      'Emulator seed of $documentPath failed (${response.statusCode}): '
      '${response.body}',
    );
  }
}

int _uniqueCounter = 0;
String _uniqueEmail(String label) =>
    '$label-${DateTime.now().microsecondsSinceEpoch}-${_uniqueCounter++}@test.appstone';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_pointAtEmulators);

  tearDown(() async {
    await FirebaseAuth.instance.signOut();
  });

  group('AuthGuard', () {
    testWidgets('signed out -> shows the login page, not the guarded child', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AuthGuard(child: Scaffold(body: Text('SECRET SCREEN'))),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SECRET SCREEN'), findsNothing);
      // LoginPage's own content proves the guard actually redirected.
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Username or Email'), findsOneWidget);
    });

    testWidgets('signed in -> shows the guarded child', (tester) async {
      final email = _uniqueEmail('authguard');
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: 'Passw0rd!',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthGuard(child: Scaffold(body: Text('SECRET SCREEN'))),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SECRET SCREEN'), findsOneWidget);
    });
  });

  group('PremiumGuard', () {
    Future<void> seedStudent({required bool premium}) async {
      final groupId = 'grp-${DateTime.now().microsecondsSinceEpoch}';
      await _seed('groups/$groupId', {
        'name': 'Test Group',
        'isPremium': premium,
        'students': const <String>[],
        'createdAt': DateTime.now(),
      });

      final email = _uniqueEmail('student');
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: 'Passw0rd!',
      );
      await _seed('studentIndex/${cred.user!.uid}', {
        'studentId': 'STU-TEST',
        'groupId': groupId,
        'email': email,
      });

      // Belt-and-braces: read the group doc back through the SDK (not the
      // REST seed path) so a genuine propagation lag between the emulator's
      // REST and gRPC listeners - not app logic - can't masquerade as a
      // guard bug.
      final readBack = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .get();
      if (readBack.data()?['isPremium'] != premium) {
        throw StateError(
          'Fixture not visible yet: groups/$groupId isPremium='
          '${readBack.data()?['isPremium']}, expected $premium',
        );
      }
    }

    testWidgets('free group -> blocked with the premium-required screen', (
      tester,
    ) async {
      await seedStudent(premium: false);

      await tester.pumpWidget(
        const MaterialApp(
          home: PremiumGuard(child: Scaffold(body: Text('PREMIUM SCREEN'))),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PREMIUM SCREEN'), findsNothing);
      expect(find.text('This is a premium feature'), findsOneWidget);
    });

    testWidgets('premium group -> lets the student through', (tester) async {
      await seedStudent(premium: true);

      await tester.pumpWidget(
        const MaterialApp(
          home: PremiumGuard(child: Scaffold(body: Text('PREMIUM SCREEN'))),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PREMIUM SCREEN'), findsOneWidget);
    });
  });

  group('AdminPortalPage role gating', () {
    // AdminPortalPage itself just trusts the `role` param (AuthGate is what
    // resolves it from Firestore before ever building this page) - but the
    // point of this test is the RENDERED sidebar, which is real app logic:
    // the Admins/Audit Log nav buttons only appear for AdminRole.owner.
    // Seeding a matching `admins` doc is what lets AdminRepository's
    // groupsStream() read past firestore.rules' isActiveAdmin() check.
    Future<void> pumpPortal(WidgetTester tester, AdminRole role) async {
      final email = _uniqueEmail('admin');
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: 'Passw0rd!',
      );
      await _seed('admins/$email', {
        'email': email,
        'name': 'Test Admin',
        'role': role.name,
        'active': true,
        'uid': cred.user!.uid,
        'createdAt': DateTime.now(),
      });

      await tester.pumpWidget(MaterialApp(home: AdminPortalPage(role: role)));
      await tester.pumpAndSettle();
    }

    testWidgets('plain admin does not see Admins or Audit Log', (tester) async {
      await pumpPortal(tester, AdminRole.admin);

      expect(find.text('Admins'), findsNothing);
      expect(find.text('Audit Log'), findsNothing);
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('owner sees Admins and Audit Log', (tester) async {
      await pumpPortal(tester, AdminRole.owner);

      expect(find.text('Admins'), findsOneWidget);
      expect(find.text('Audit Log'), findsOneWidget);
    });
  });
}
