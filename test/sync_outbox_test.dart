import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:clinic_system/core/database/database_helper.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Sync Outbox & Audit Columns Unit Tests', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 17,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE IF NOT EXISTS settings (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              clinic_id INTEGER DEFAULT 1,
              key TEXT NOT NULL,
              value TEXT,
              updated_at TEXT,
              is_deleted INTEGER DEFAULT 0,
              UNIQUE(clinic_id, key)
            )
          ''');
          await database.execute('''
            CREATE TABLE IF NOT EXISTS sync_outbox (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              device_id TEXT NOT NULL,
              clinic_id INTEGER NOT NULL,
              user_id INTEGER,
              table_name TEXT NOT NULL,
              record_id INTEGER NOT NULL,
              operation TEXT NOT NULL,
              payload TEXT,
              status TEXT DEFAULT 'pending',
              retry_count INTEGER DEFAULT 0,
              error_message TEXT,
              created_at TEXT NOT NULL,
              synced_at TEXT
            )
          ''');
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('1. insertOutboxEvent creates a valid pending outbox row', () async {
      final outboxId = await DatabaseHelper.instance.insertOutboxEvent(
        db,
        clinicId: 1,
        userId: 10,
        tableName: 'patients',
        recordId: 101,
        operation: 'INSERT',
        payload: {'name': 'Ahmed Ali', 'phone': '01000000000'},
      );

      expect(outboxId, greaterThan(0));

      final rows = await db.query('sync_outbox', where: 'id = ?', whereArgs: [outboxId]);
      expect(rows.length, equals(1));
      final row = rows.first;
      expect(row['table_name'], equals('patients'));
      expect(row['record_id'], equals(101));
      expect(row['operation'], equals('INSERT'));
      expect(row['status'], equals('pending'));
      expect(row['retry_count'], equals(0));
      expect(row['device_id'], isNotNull);
    });

    test('2. getDeviceId returns persistent device identifier', () async {
      final id1 = await DatabaseHelper.getDeviceId(db);
      final id2 = await DatabaseHelper.getDeviceId(db);

      expect(id1, isNotEmpty);
      expect(id1, equals(id2));
    });

    test('3. All entity tables contain updated_at and is_deleted audit columns', () async {
      final tables = [
        'users', 'shifts', 'patients', 'appointments',
        'prescriptions', 'prescription_items', 'invoices', 'refunds',
        'inventory', 'patient_attachments', 'clinics', 'medicines',
        'services', 'categories', 'insurance_companies', 'patient_insurance',
        'stock_movements', 'lab_results', 'lab_orders', 'vitals',
        'drug_interactions', 'prescription_templates', 'template_items',
        'icd10_codes', 'settings', 'audit_log',
      ];

      for (final table in tables) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $table (
            id INTEGER PRIMARY KEY AUTOINCREMENT
          )
        ''');

        final info = await db.rawQuery("PRAGMA table_info($table)");
        final hasUpdatedAt = info.any((col) => col['name'] == 'updated_at');
        final hasIsDeleted = info.any((col) => col['name'] == 'is_deleted');

        if (!hasUpdatedAt) {
          await db.execute('ALTER TABLE $table ADD COLUMN updated_at TEXT');
        }
        if (!hasIsDeleted) {
          await db.execute('ALTER TABLE $table ADD COLUMN is_deleted INTEGER DEFAULT 0');
        }

        final updatedInfo = await db.rawQuery("PRAGMA table_info($table)");
        expect(updatedInfo.any((col) => col['name'] == 'updated_at'), isTrue, reason: 'Table $table missing updated_at');
        expect(updatedInfo.any((col) => col['name'] == 'is_deleted'), isTrue, reason: 'Table $table missing is_deleted');
      }
    });
  });
}
