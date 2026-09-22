import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:clinic_system/core/database/database_helper.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
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

  group('Phase 1 - SQLite Database Migration & Sync Tables Unit Tests', () {
    late Database db;

    setUp(() async {
      db = await DatabaseHelper.instance.database;
    });

    test('1. Database version is upgraded to version 18', () async {
      final version = await db.getVersion();
      expect(version, equals(18));
    });

    test('2. All 11 sync tables contain the 5 required sync columns', () async {
      final syncTables = [
        'clinics',
        'users',
        'patients',
        'appointments',
        'waiting_queue',
        'medical_records',
        'prescriptions',
        'invoices',
        'invoice_items',
        'inventory',
        'shifts',
      ];

      for (final table in syncTables) {
        final tableInfo = await db.rawQuery('PRAGMA table_info($table)');
        final columnNames = tableInfo.map((c) => c['name'] as String).toList();

        expect(columnNames, contains('remote_id'), reason: '$table missing remote_id');
        expect(columnNames, contains('sync_status'), reason: '$table missing sync_status');
        expect(columnNames, contains('updated_at'), reason: '$table missing updated_at');
        expect(columnNames, contains('deleted_at'), reason: '$table missing deleted_at');
        expect(columnNames, contains('sync_version'), reason: '$table missing sync_version');
      }
    });

    test('3. Sync system tables (sync_queue, sync_metadata, sync_log) exist', () async {
      final tablesRes = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tableNames = tablesRes.map((t) => t['name'] as String).toList();

      expect(tableNames, contains('sync_queue'));
      expect(tableNames, contains('sync_metadata'));
      expect(tableNames, contains('sync_log'));
    });

    test('4. Helper functions (addToSyncQueue, insertSyncLog, getOrCreateDeviceId) execute cleanly', () async {
      final deviceId = await DatabaseHelper.instance.getOrCreateDeviceId();
      expect(deviceId, isNotEmpty);

      // Add item to sync_queue
      final queueId = await DatabaseHelper.instance.addToSyncQueue(
        tableName: 'patients',
        recordId: 101,
        remoteId: 'f47ac10b-58cc-4372-a567-0e02b2c3d479',
        operation: 'INSERT',
        payload: {'name': 'Test Patient'},
      );
      expect(queueId, greaterThan(0));

      final pending = await DatabaseHelper.instance.getPendingSyncQueue();
      expect(pending, isNotEmpty);

      // Mark synced
      await DatabaseHelper.instance.markSyncQueueItemSynced(queueId);

      // Insert log entry
      final logId = await DatabaseHelper.instance.insertSyncLog(
        tableName: 'patients',
        operation: 'INSERT',
        localId: 101,
        remoteId: 'f47ac10b-58cc-4372-a567-0e02b2c3d479',
        status: 'success',
        details: 'Unit test insert log',
        deviceId: deviceId,
      );
      expect(logId, greaterThan(0));
    });

    test('5. Unique index idx_{table}_remote_id exists for all 11 sync tables', () async {
      final syncTables = [
        'clinics',
        'users',
        'patients',
        'appointments',
        'waiting_queue',
        'medical_records',
        'prescriptions',
        'invoices',
        'invoice_items',
        'inventory',
        'shifts',
      ];

      for (final table in syncTables) {
        final indexList = await db.rawQuery("PRAGMA index_list($table)");
        final indexNames = indexList.map((i) => i['name'] as String).toList();
        expect(indexNames, contains('idx_${table}_remote_id'), reason: 'Table $table missing remote_id unique index');
      }
    });
  });
}
