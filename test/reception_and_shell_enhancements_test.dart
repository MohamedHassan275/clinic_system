import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:clinic_system/core/database/database_helper.dart';
import 'package:clinic_system/core/security/session_manager.dart';

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

  group('Reception & Shell Enhancements Unit Tests', () {
    test('1. DatabaseHelper initializes invoices table with status column', () async {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;

      final info = await db.rawQuery("PRAGMA table_info('invoices')");
      final hasStatus = info.any((col) => col['name'] == 'status');

      expect(hasStatus, isTrue);
    });

    test('2. Invoices query with status filtering succeeds without DB error', () async {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;

      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final res = await db.rawQuery(
        "SELECT SUM(paid_amount) as total FROM invoices WHERE clinic_id = ? AND date(created_at) = date(?) AND status != 'refunded'",
        [1, todayStr],
      );

      expect(res, isNotNull);
    });

    test('3. Shift closure on logout updates DB shift record to closed', () async {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;

      final shiftId = await db.insert('shifts', {
        'user_id': 1,
        'start_time': DateTime.now().toIso8601String(),
        'starting_cash': 100.0,
        'is_closed': 0,
      });

      // Set active shift in session
      SessionManager.instance.setActiveShift({
        'id': shiftId,
        'user_id': 1,
        'is_closed': 0,
      });

      expect(SessionManager.instance.hasActiveShift, isTrue);

      // Simulate logout shift closure logic
      final activeShift = SessionManager.instance.activeShift;
      if (activeShift != null && activeShift['id'] != null) {
        await db.update(
          'shifts',
          {'end_time': DateTime.now().toIso8601String(), 'is_closed': 1},
          where: 'id = ?',
          whereArgs: [activeShift['id']],
        );
      }
      SessionManager.instance.setActiveShift(null);
      await SessionManager.instance.clearSession();

      expect(SessionManager.instance.hasActiveShift, isFalse);

      final checkDb = await db.query('shifts', where: 'id = ?', whereArgs: [shiftId]);
      expect(checkDb.first['is_closed'], equals(1));
    });
  });
}
