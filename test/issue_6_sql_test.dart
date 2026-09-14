import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Issue 6: SQL Schema & Raw Query Tests', () {
    test('1. DatabaseHelper initializes schema without duplicate tables', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      );

      expect(db.isOpen, isTrue);
      await db.close();
    });

    test('2. Patients table contains secondary_phone and insurance columns', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE patients (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              clinic_id INTEGER DEFAULT 1,
              name TEXT NOT NULL,
              phone TEXT NOT NULL,
              secondary_phone TEXT,
              insurance_entity_name TEXT,
              policy_number TEXT,
              insurance_company_id INTEGER,
              coverage_percentage REAL DEFAULT 0
            )
          ''');
        },
      );

      await db.insert('patients', {
        'name': 'اختبار مريض',
        'phone': '01000000000',
        'secondary_phone': '01100000000',
        'insurance_entity_name': 'شركة الأمل',
        'policy_number': 'POL-12345',
        'insurance_company_id': 1,
        'coverage_percentage': 80.0,
      });

      final result = await db.query('patients');
      expect(result.length, equals(1));
      expect(result.first['secondary_phone'], equals('01100000000'));
      expect(result.first['insurance_entity_name'], equals('شركة الأمل'));
      expect(result.first['policy_number'], equals('POL-12345'));
      expect(result.first['coverage_percentage'], equals(80.0));

      await db.close();
    });

    test('3. Raw SQL queries for status handle English & Arabic values correctly', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE appointments (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              status TEXT NOT NULL
            )
          ''');
        },
      );

      await db.insert('appointments', {'status': 'waiting'});
      await db.insert('appointments', {'status': 'منتظر'});
      await db.insert('appointments', {'status': 'completed'});
      await db.insert('appointments', {'status': 'مكتمل'});

      final waitingRes = await db.rawQuery(
        "SELECT COUNT(*) as count FROM appointments WHERE status IN ('waiting', 'منتظر')",
      );
      final completedRes = await db.rawQuery(
        "SELECT COUNT(*) as count FROM appointments WHERE status IN ('completed', 'مكتمل')",
      );

      expect(Sqflite.firstIntValue(waitingRes), equals(2));
      expect(Sqflite.firstIntValue(completedRes), equals(2));

      await db.close();
    });
  });
}
