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
  });
}
