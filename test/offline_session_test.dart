import 'dart:async';

import 'package:appstone/services/friendly_error.dart';
import 'package:appstone/services/session_cache.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Guards the two pieces of logic that decide whether the app opens offline.
//
// Both are pure: isOfflineError is a classifier, and the session cache is
// SharedPreferences. Neither needs Firebase, a network, or an emulator.
void main() {
  group('isOfflineError', () {
    test('a Firestore transport failure is offline, a refusal is not', () {
      // The whole point of the predicate: unavailable means "could not ask",
      // permission-denied means "asked, and the answer is no". Only the second
      // may end a session.
      expect(
        isOfflineError(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
        isTrue,
      );
      expect(
        isOfflineError(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'deadline-exceeded',
          ),
        ),
        isTrue,
      );
      expect(
        isOfflineError(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        isFalse,
      );
      expect(
        isOfflineError(
          FirebaseException(plugin: 'cloud_firestore', code: 'not-found'),
        ),
        isFalse,
      );
    });

    test('timeouts and browser transport errors count as offline', () {
      expect(isOfflineError(TimeoutException('slow')), isTrue);
      // What a failed fetch looks like coming out of a web build.
      expect(
        isOfflineError(Exception('XMLHttpRequest error.')),
        isTrue,
      );
    });

    test('an ordinary failure is not mistaken for being offline', () {
      expect(isOfflineError(Exception('bad input')), isFalse);
      expect(isOfflineError(StateError('not authorized')), isFalse);
    });
  });

  group('student session cache', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('round-trips everything the dashboard needs', () async {
      await saveStudentSession(
        studentId: 'STU001',
        groupId: 'group-1',
        studentName: 'Ana Cruz',
        groupName: 'Team Falcon',
        isPremium: true,
        mustChangePassword: true,
      );

      final cached = await loadStudentSession();
      expect(cached, isNotNull);
      expect(cached!.studentId, 'STU001');
      expect(cached.groupId, 'group-1');
      expect(cached.studentName, 'Ana Cruz');
      expect(cached.groupName, 'Team Falcon');
      expect(cached.isPremium, isTrue);
      expect(cached.mustChangePassword, isTrue);
    });

    test('no session reads as null rather than an empty one', () async {
      expect(await loadStudentSession(), isNull);
    });

    test('a session saved before this cache existed still restores', () async {
      // Only the two original keys are present, which is what an upgrading
      // student's device looks like. They must stay signed in.
      SharedPreferences.setMockInitialValues(<String, Object>{
        studentIdPrefsKey: 'STU042',
        groupIdPrefsKey: 'group-9',
      });

      final cached = await loadStudentSession();
      expect(cached, isNotNull);
      expect(cached!.studentId, 'STU042');
      expect(cached.groupId, 'group-9');
      expect(cached.isPremium, isFalse);
    });

    test('a cached session is only restorable by the account that saved it',
        () async {
      // The case this exists for: an admin signs in on a machine a student used
      // earlier, then opens it offline. Restoring the student's dashboard for
      // the admin would be a serious mix-up, so a uid mismatch blocks it.
      await saveStudentSession(
        studentId: 'STU001',
        groupId: 'group-1',
        studentName: 'Ana Cruz',
        groupName: 'Team Falcon',
        isPremium: false,
        mustChangePassword: false,
        uid: 'uid-student',
      );

      final cached = await loadStudentSession();
      expect(cached!.belongsTo('uid-student'), isTrue);
      expect(cached.belongsTo('uid-admin'), isFalse);
      // No signed-in account to compare against: the saved session is all
      // there is, so it stands.
      expect(cached.belongsTo(null), isTrue);
    });

    test('a session with no uid still restores for anyone', () async {
      // Written by an older release. Refusing it would sign out every
      // upgrading student on their first offline open.
      SharedPreferences.setMockInitialValues(<String, Object>{
        studentIdPrefsKey: 'STU042',
        groupIdPrefsKey: 'group-9',
      });

      final cached = await loadStudentSession();
      expect(cached!.uid, isNull);
      expect(cached.belongsTo('uid-anyone'), isTrue);
    });

    test('clearing removes every field, not just the ids', () async {
      await saveStudentSession(
        studentId: 'STU001',
        groupId: 'group-1',
        studentName: 'Ana Cruz',
        groupName: 'Team Falcon',
        isPremium: true,
        mustChangePassword: false,
        uid: 'uid-student',
      );
      await clearStudentSession();

      expect(await loadStudentSession(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });
  });
}
