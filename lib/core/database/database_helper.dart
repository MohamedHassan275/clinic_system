import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../common/error_handler/app_logger.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('clinic_system.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final Directory docDir = await getApplicationDocumentsDirectory();
    final String path = join(docDir.path, filePath);

    AppLogger.info('Initializing SQLite database at: $path');

    final db = await openDatabase(
      path,
      version: 10,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        AppLogger.info('Upgrading database version from $oldVersion to $newVersion...');
        await _onUpgradeMigration(db, oldVersion, newVersion);
      },
    );

    await _checkAndSeedUsersIfEmpty(db);
    return db;
  }

  Future<void> _onUpgradeMigration(Database db, int oldVersion, int newVersion) async {
    // 1. Create new tables if not exists
    await _createTables(db);

    final oldTables = [
      'users',
      'shifts',
      'patients',
      'appointments',
      'prescriptions',
      'prescription_items',
      'invoices',
      'inventory',
      'lab_results',
      'patient_attachments'
    ];

    for (var table in oldTables) {
      try {
        await db.execute('ALTER TABLE $table ADD COLUMN clinic_id INTEGER DEFAULT 1');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE $table ADD COLUMN updated_at TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE $table ADD COLUMN is_deleted INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE $table ADD COLUMN last_synced_at TEXT');
      } catch (_) {}
    }

    try {
      await db.execute('ALTER TABLE users ADD COLUMN password_hash TEXT');
    } catch (_) {}

    // Create Indexes, Sanitize Settings Keys & Convert Arabic DB values to English
    await _createIndexes(db);
    await sanitizeExtraneousSettingsKeys(db);
    await sanitizeArabicValuesToEnglish(db);
  }

  Future<void> sanitizeArabicValuesToEnglish(Database db) async {
    try {
      await db.execute("UPDATE appointments SET status = 'waiting' WHERE status IN ('في الانتظار', 'منتظر')");
      await db.execute("UPDATE appointments SET status = 'in_progress' WHERE status IN ('جاري الكشف', 'في الكشف')");
      await db.execute("UPDATE appointments SET status = 'completed' WHERE status = 'مكتمل'");
      await db.execute("UPDATE appointments SET status = 'cancelled' WHERE status = 'ملغى'");
      
      await db.execute("UPDATE appointments SET type = 'new_consultation' WHERE type = 'كشف جديد'");
      await db.execute("UPDATE appointments SET type = 'follow_up' WHERE type IN ('إعادة / استشارة', 'استشارة')");
      await db.execute("UPDATE appointments SET type = 'lab_review' WHERE type IN ('متابعة نتيجه تحاليل', 'متابعة نتائج')");

      await db.execute("UPDATE patients SET gender = 'male' WHERE gender = 'ذكر'");
      await db.execute("UPDATE patients SET gender = 'female' WHERE gender = 'أنثى'");
    } catch (e) {
      AppLogger.error('Failed sanitizing Arabic values to English in DB: $e');
    }
  }

  Future<void> _checkAndSeedUsersIfEmpty(Database db) async {
    final countRes = await db.rawQuery('SELECT COUNT(*) as count FROM users');
    final count = countRes.isNotEmpty ? (countRes.first['count'] as int? ?? 0) : 0;
    if (count == 0) {
      await _seedInitialData(db);
    }
  }

  Future<void> _createDB(Database db, int version) async {
    AppLogger.info('Creating SQLite tables and indexes...');
    await _createTables(db);
    await _createIndexes(db);
    await _seedInitialData(db);
  }

  Future<void> _createTables(Database db) async {
    // 1. Clinics Table (Multi-tenant)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clinics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT,
        phone TEXT,
        email TEXT,
        logo_path TEXT,
        currency TEXT DEFAULT 'EGP',
        subscription_plan TEXT DEFAULT 'starter',
        subscription_start TEXT,
        subscription_expiry TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // 2. Users Table (PROTECTED - Never Cleared)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER DEFAULT 1,
        username TEXT UNIQUE NOT NULL,
        password TEXT,
        password_hash TEXT,
        full_name TEXT NOT NULL,
        role TEXT NOT NULL,
        branch TEXT DEFAULT 'جميع الفروع (سوبر أدمن)',
        permissions_json TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        last_synced_at TEXT,
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE
      )
    ''');

    // 3. Shifts Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER DEFAULT 1,
        user_id INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        starting_cash REAL NOT NULL,
        ending_cash REAL DEFAULT 0.0,
        is_closed INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        created_at TEXT,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        last_synced_at TEXT,
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 4. Patients Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS patients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER DEFAULT 1,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        national_id TEXT,
        age INTEGER,
        gender TEXT,
        medical_history TEXT,
        allergies TEXT,
        dob TEXT,
        blood_group TEXT DEFAULT 'غير محدد',
        female_status TEXT DEFAULT 'طبيعي',
        emergency_phone TEXT,
        contract_entity TEXT DEFAULT 'نقدي (خاص)',
        chronic_diseases TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        last_synced_at TEXT,
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE
      )
    ''');

    // 5. Appointments Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS appointments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER DEFAULT 1,
        patient_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        shift_id INTEGER NOT NULL,
        appointment_date TEXT NOT NULL,
        time_slot TEXT NOT NULL,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        fee REAL DEFAULT 0.0,
        doctor_name TEXT,
        notes TEXT,
        priority TEXT DEFAULT 'عادي',
        created_at TEXT,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        last_synced_at TEXT,
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE,
        FOREIGN KEY (patient_id) REFERENCES patients (id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (shift_id) REFERENCES shifts (id) ON DELETE CASCADE
      )
    ''');

    // 6. Prescriptions Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS prescriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER DEFAULT 1,
        appointment_id INTEGER,
        patient_id INTEGER NOT NULL,
        doctor_id INTEGER NOT NULL,
        diagnosis TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        last_synced_at TEXT,
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE,
        FOREIGN KEY (patient_id) REFERENCES patients (id) ON DELETE CASCADE,
        FOREIGN KEY (doctor_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 7. Prescription Items Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS prescription_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER DEFAULT 1,
        prescription_id INTEGER NOT NULL,
        medicine_name TEXT NOT NULL,
        dosage TEXT NOT NULL,
        frequency TEXT NOT NULL,
        duration TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        last_synced_at TEXT,
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE,
        FOREIGN KEY (prescription_id) REFERENCES prescriptions (id) ON DELETE CASCADE
      )
    ''');

    // 8. Invoices Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER DEFAULT 1,
        patient_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        shift_id INTEGER NOT NULL,
        total_amount REAL NOT NULL,
        discount REAL DEFAULT 0.0,
        paid_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        last_synced_at TEXT,
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE,
        FOREIGN KEY (patient_id) REFERENCES patients (id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (shift_id) REFERENCES shifts (id) ON DELETE CASCADE
      )
    ''');

    // 9. Inventory Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER DEFAULT 1,
        item_name TEXT NOT NULL,
        barcode TEXT,
        category TEXT DEFAULT 'مستلزمات عامة',
        lot_number TEXT,
        quantity INTEGER NOT NULL DEFAULT 0,
        min_threshold INTEGER NOT NULL DEFAULT 10,
        unit_price REAL NOT NULL DEFAULT 0.0,
        expiry_date TEXT,
        storage_condition TEXT DEFAULT 'درجة حرارة الغرفة 20-25°C',
        unit_measure TEXT DEFAULT 'عبوة',
        supplier_name TEXT,
        created_at TEXT,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        last_synced_at TEXT,
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE
      )
    ''');

    // 10. Lab Results Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lab_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER DEFAULT 1,
        patient_id INTEGER NOT NULL,
        test_name TEXT NOT NULL,
        test_date TEXT NOT NULL,
        measured_value TEXT NOT NULL,
        unit TEXT NOT NULL,
        reference_range TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        last_synced_at TEXT,
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE,
        FOREIGN KEY (patient_id) REFERENCES patients (id) ON DELETE CASCADE
      )
    ''');

    // 11. Patient Attachments Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS patient_attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER DEFAULT 1,
        patient_id INTEGER NOT NULL,
        file_name TEXT NOT NULL,
        file_type TEXT NOT NULL,
        file_path TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        last_synced_at TEXT,
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE,
        FOREIGN KEY (patient_id) REFERENCES patients (id) ON DELETE CASCADE
      )
    ''');

    // 12. Medicines Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS medicines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER DEFAULT 1,
        trade_name TEXT NOT NULL,
        scientific_name TEXT,
        category TEXT,
        default_dosage TEXT,
        default_frequency TEXT,
        default_duration TEXT,
        notes TEXT,
        is_favorite INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        last_synced_at TEXT,
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE
      )
    ''');

    // 13. Services Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS services (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER DEFAULT 1,
        name TEXT NOT NULL,
        category TEXT,
        price REAL NOT NULL,
        duration_minutes INTEGER,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        last_synced_at TEXT,
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE
      )
    ''');

    // 14. Settings Table (Protected Core Keys)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER DEFAULT 1,
        key TEXT NOT NULL,
        value TEXT,
        updated_at TEXT,
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE,
        UNIQUE(clinic_id, key)
      )
    ''');

    // 15. Audit Log Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER DEFAULT 1,
        user_id INTEGER,
        action TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id INTEGER,
        old_value TEXT,
        new_value TEXT,
        created_at TEXT,
        FOREIGN KEY (clinic_id) REFERENCES clinics(id),
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // 16. Insurance Companies Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS insurance_companies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER DEFAULT 1,
        name TEXT NOT NULL,
        contact_person TEXT,
        phone TEXT,
        email TEXT,
        discount_percentage REAL,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        last_synced_at TEXT,
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE
      )
    ''');

    // 17. Patient Insurance Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS patient_insurance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id INTEGER NOT NULL,
        insurance_company_id INTEGER NOT NULL,
        policy_number TEXT,
        card_number TEXT,
        expiry_date TEXT,
        coverage_percentage REAL,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        last_synced_at TEXT,
        FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE,
        FOREIGN KEY (insurance_company_id) REFERENCES insurance_companies(id) ON DELETE CASCADE
      )
    ''');

    // 18. Sync Queue Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER DEFAULT 1,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT,
        status TEXT DEFAULT 'pending',
        retry_count INTEGER DEFAULT 0,
        created_at TEXT,
        synced_at TEXT
      )
    ''');

    // =========================================================================
    // NEW TABLES FOR DOCTOR & SECRETARY PORTALS REBUILD
    // =========================================================================

    // 19. ICD-10 Codes Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS icd10_codes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE NOT NULL,
        description_ar TEXT NOT NULL,
        description_en TEXT,
        category TEXT
      )
    ''');

    // 20. Drug Interactions Table (Using FK to medicines(id))
    await db.execute('''
      CREATE TABLE IF NOT EXISTS drug_interactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        drug_a_id INTEGER NOT NULL,
        drug_b_id INTEGER NOT NULL,
        severity TEXT NOT NULL,
        description TEXT NOT NULL,
        FOREIGN KEY (drug_a_id) REFERENCES medicines(id) ON DELETE CASCADE,
        FOREIGN KEY (drug_b_id) REFERENCES medicines(id) ON DELETE CASCADE,
        UNIQUE(drug_a_id, drug_b_id)
      )
    ''');

    // 21. Prescription Templates Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS prescription_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        doctor_id INTEGER NOT NULL,
        template_name TEXT NOT NULL,
        category TEXT,
        notes TEXT,
        FOREIGN KEY (doctor_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // 22. Template Items Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS template_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_id INTEGER NOT NULL,
        medicine_name TEXT NOT NULL,
        dosage TEXT NOT NULL,
        frequency TEXT NOT NULL,
        duration TEXT NOT NULL,
        FOREIGN KEY (template_id) REFERENCES prescription_templates(id) ON DELETE CASCADE
      )
    ''');

    // 23. Patient Vitals Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vitals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id INTEGER NOT NULL,
        appointment_id INTEGER,
        bp_systolic INTEGER,
        bp_diastolic INTEGER,
        pulse_rate INTEGER,
        temperature REAL,
        blood_sugar INTEGER,
        weight REAL,
        height REAL,
        bmi REAL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE
      )
    ''');

    // 24. Lab & Radiology Orders Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lab_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id INTEGER NOT NULL,
        doctor_id INTEGER NOT NULL,
        appointment_id INTEGER,
        test_name TEXT NOT NULL,
        category TEXT,
        status TEXT DEFAULT 'pending',
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE,
        FOREIGN KEY (doctor_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createIndexes(Database db) async {
    AppLogger.info('Creating database indexes...');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_patients_clinic ON patients (clinic_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_appointments_clinic_date ON appointments (clinic_id, appointment_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_invoices_clinic_date ON invoices (clinic_id, created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_users_username ON users (username)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_patients_national_id ON patients (national_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_vitals_patient ON vitals (patient_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_lab_orders_patient ON lab_orders (patient_id)');
  }

  /// Clean extraneous settings keys, protecting only core settings keys
  Future<void> sanitizeExtraneousSettingsKeys(DatabaseExecutor db) async {
    final allowedKeys = [
      'currency',
      'language',
      'working_hours',
      'working_days',
      'timezone',
      'date_format',
      'clinic_name',
      'clinic_logo',
      'legal_name',
      'tax_id',
      'commercial_register',
    ];
    final placeholders = allowedKeys.map((_) => '?').join(', ');
    await db.delete(
      'settings',
      where: 'key NOT IN ($placeholders)',
      whereArgs: allowedKeys,
    );
  }

  /// Clear all transient test/demo data in operational tables while STRICTLY PROTECTING users, clinics, and settings
  Future<void> sanitizeTransientOperationalData() async {
    final db = await database;
    await db.transaction((txn) async {
      final tablesToClear = [
        'shifts',
        'patients',
        'appointments',
        'prescriptions',
        'prescription_items',
        'invoices',
        'inventory',
        'lab_results',
        'patient_attachments',
        'medicines',
        'services',
        'audit_log',
        'insurance_companies',
        'patient_insurance',
        'sync_queue',
        'vitals',
        'lab_orders',
      ];

      for (var table in tablesToClear) {
        await txn.delete(table);
      }

      await sanitizeExtraneousSettingsKeys(txn);
    });
    AppLogger.info('Sanitized operational tables, protecting users, clinics, and core settings.');
  }

  Future<void> _seedInitialData(Database db) async {
    AppLogger.info('Seeding initial default clinic, settings, and users...');
    final nowStr = DateTime.now().toIso8601String();

    // 1. Seed Default Clinic "عيادتي" (id = 1)
    final clinicCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM clinics WHERE id = 1');
    final clinicCount = clinicCountRes.isNotEmpty ? (clinicCountRes.first['count'] as int? ?? 0) : 0;
    if (clinicCount == 0) {
      await db.insert('clinics', {
        'id': 1,
        'name': 'عيادتي',
        'address': 'الفرع الرئيسي',
        'phone': '01000000000',
        'currency': 'EGP',
        'subscription_plan': 'starter',
        'is_active': 1,
        'created_at': nowStr,
        'updated_at': nowStr,
      });
    }

    // 2. Seed Default Settings
    final settingsKeys = [
      {'key': 'currency', 'value': 'EGP'},
      {'key': 'language', 'value': 'ar'},
      {'key': 'working_hours', 'value': '09:00 - 21:00'},
    ];
    for (var setting in settingsKeys) {
      await db.rawInsert('''
        INSERT OR IGNORE INTO settings (clinic_id, key, value, updated_at)
        VALUES (1, ?, ?, ?)
      ''', [setting['key'], setting['value'], nowStr]);
    }

    // 3. Seed Default System Users (mo_hassan and dr_hassan)
    final allPermissions = jsonEncode([
      'dashboard',
      'appointments',
      'waiting_room',
      'emr',
      'consultation',
      'billing',
      'inventory',
      'reports',
      'settings',
    ]);

    final doctorPermissions = jsonEncode([
      'dashboard',
      'appointments',
      'waiting_room',
      'emr',
      'consultation',
    ]);

    // Super Admin User
    final adminCountRes = await db.rawQuery("SELECT COUNT(*) as count FROM users WHERE username = 'mo_hassan'");
    final adminCount = adminCountRes.isNotEmpty ? (adminCountRes.first['count'] as int? ?? 0) : 0;
    if (adminCount == 0) {
      await db.insert('users', {
        'clinic_id': 1,
        'username': 'mo_hassan',
        'password': '123456',
        'full_name': 'mohamed hassan',
        'role': 'admin',
        'branch': 'جميع الفروع (سوبر أدمن)',
        'permissions_json': allPermissions,
        'is_active': 1,
        'created_at': nowStr,
      });
    }

    // Doctor User
    final doctorCountRes = await db.rawQuery("SELECT COUNT(*) as count FROM users WHERE username = 'dr_hassan'");
    final doctorCount = doctorCountRes.isNotEmpty ? (doctorCountRes.first['count'] as int? ?? 0) : 0;
    if (doctorCount == 0) {
      await db.insert('users', {
        'clinic_id': 1,
        'username': 'dr_hassan',
        'password': '123456',
        'full_name': 'د. محمد حسن (طبيب معالج)',
        'role': 'doctor',
        'branch': 'فرع السلام (الرئيسي)',
        'permissions_json': doctorPermissions,
        'is_active': 1,
        'created_at': nowStr,
      });
    }

    AppLogger.info('Database seeded successfully with clinic "عيادتي", default settings, and initial users mo_hassan & dr_hassan.');
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
  }
}
