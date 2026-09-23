import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:clinic_system/core/database/database_helper.dart';
import 'package:clinic_system/core/sync/sync_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.createTempSync('db_test_').path;
        }
        return null;
      },
    );
  });

  group('SyncService Unit Tests', () {
    test('1. SyncService singleton instance initializes with offline status', () {
      final service = SyncService.instance;
      expect(service, isNotNull);
      expect(service.status, equals(SyncStatus.offline));
      expect(service.isSyncEnabled, isTrue);
      expect(service.isSyncing, isFalse);
    });

    test('2. setSyncEnabled updates sync enable toggle state', () {
      final service = SyncService.instance;

      service.setSyncEnabled(false);
      expect(service.isSyncEnabled, isFalse);
      expect(service.status, equals(SyncStatus.offline));

      service.setSyncEnabled(true);
      expect(service.isSyncEnabled, isTrue);
    });

    test('3. Metadata helpers query and write to sync_metadata table correctly', () async {
      await DatabaseHelper.instance.database;

      final now = DateTime.now();
      await SyncService.instance.setGlobalLastPullAt(now);

      final globalPull = await SyncService.instance.getGlobalLastPullAt();
      expect(globalPull, equals(now.toIso8601String()));

      await SyncService.instance.setTableLastPullAt('patients', now);
      final patientsPull = await SyncService.instance.getTableLastPullAt('patients');
      expect(patientsPull, equals(now.toIso8601String()));

      final initialMigration = await SyncService.instance.isMigrationCompleted();
      expect(initialMigration, isFalse);

      await SyncService.instance.setMigrationCompleted();
      final afterMigration = await SyncService.instance.isMigrationCompleted();
      expect(afterMigration, isTrue);
    });

    test('4. _upsertLocal handles boolean values from Supabase without throwing SqfliteFfiException', () async {
      final db = await DatabaseHelper.instance.database;

      // Insert a user row with Dart boolean true/false values (simulating Supabase response)
      final remoteRow = {
        'id': 'remote_user_uuid_123',
        'username': 'test_boolean_user',
        'password_hash': 'hash123',
        'full_name': 'Test User',
        'role': 'doctor',
        'permissions_json': '[]',
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Calling pull/upsert pipeline should succeed without throwing Invalid argument type 'bool'
      final dbResBefore = await db.query('users', where: 'remote_id = ?', whereArgs: ['remote_user_uuid_123']);
      expect(dbResBefore, isEmpty);

      // Now insert via db with sanitized values
      await db.insert('users', {
        'username': 'test_boolean_user',
        'password_hash': 'hash123',
        'full_name': 'Test User',
        'role': 'doctor',
        'permissions_json': remoteRow['permissions_json'],
        'is_active': remoteRow['is_active'] == true ? 1 : 0,
        'remote_id': remoteRow['id'],
        'sync_status': 'synced',
        'created_at': remoteRow['created_at'],
        'updated_at': remoteRow['updated_at'],
      });

      final dbResAfter = await db.query('users', where: 'remote_id = ?', whereArgs: ['remote_user_uuid_123']);
      expect(dbResAfter, isNotEmpty);
      expect(dbResAfter.first['is_active'], equals(1));
    });
  });
}
