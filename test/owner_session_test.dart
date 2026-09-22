import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:clinic_system/core/database/database_helper.dart';
import 'package:clinic_system/core/security/session_manager.dart';
import 'package:clinic_system/modules/auth/data/repo/auth_repo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
  });

  group('Owner Account & Session Tests', () {
    final authRepo = AuthRepoImpl();
    final sessionManager = SessionManager.instance;

    setUp(() async {
      await sessionManager.clearSession();
    });

    test('1. Owner account (mo_hassan) is correctly initialized with super_admin role', () async {
      final dbHelper = DatabaseHelper.instance;
      final realDb = await dbHelper.database;

      final res = await realDb.query(
        'users',
        where: 'username = ?',
        whereArgs: ['mo_hassan'],
      );

      expect(res.isNotEmpty, isTrue);
      final userMap = res.first;
      expect(userMap['username'], equals('mo_hassan'));
      expect(userMap['role'], equals('super_admin'));
      expect(userMap['permissions_json'], equals('["*"]'));
    });

    test('2. Idempotency: Re-initialization does not duplicate owner account', () async {
      final dbHelper = DatabaseHelper.instance;
      final realDb = await dbHelper.database;

      // Trigger initialization again
      await dbHelper.database;

      final countRes = await realDb.rawQuery(
        "SELECT COUNT(*) as count FROM users WHERE username = 'mo_hassan'",
      );
      final count = countRes.first['count'] as int;
      expect(count, equals(1));
    });

    test('3. Login with mo_hassan / 123456 succeeds and retrieves valid credentials', () async {
      final loginResult = await authRepo.login(
        username: 'mo_hassan',
        password: '123456',
      );

      expect(loginResult.isRight(), isTrue);
      loginResult.fold(
        (l) => fail('Login failed: ${l.message}'),
        (user) {
          expect(user['username'], equals('mo_hassan'));
          expect(user['role'], equals('super_admin'));
        },
      );
    });

    test('4. SessionManager grants ALL permissions unconditionally for super_admin role', () {
      final superAdminUser = {
        'id': 1,
        'username': 'mo_hassan',
        'role': 'super_admin',
        'permissions_json': '["*"]',
      };

      sessionManager.setUserSession(superAdminUser);

      expect(sessionManager.isLoggedIn, isTrue);
      expect(sessionManager.hasPermission('dashboard'), isTrue);
      expect(sessionManager.hasPermission('billing'), isTrue);
      expect(sessionManager.hasPermission('unknown_random_permission'), isTrue);
      expect(sessionManager.hasPermission('settings'), isTrue);
    });
  });
}
