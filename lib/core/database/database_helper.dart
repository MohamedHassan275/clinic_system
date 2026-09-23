import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../common/error_handler/app_logger.dart';
import '../security/password_hasher.dart';

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
      version: 18,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        AppLogger.info('Upgrading database version from $oldVersion to $newVersion...');
        await _onUpgradeMigration(db, oldVersion, newVersion);
      },
    );

    await _ensureRequiredColumnsExist(db);
    await _checkAndSeedUsersIfEmpty(db);
    await _ensureOwnerAccountExists(db);
    return db;
  }

  Future<void> _ensureRequiredColumnsExist(Database db) async {
    try {
      final allTables = [
        'users', 'shifts', 'patients', 'appointments',
        'prescriptions', 'prescription_items', 'invoices', 'refunds',
        'inventory', 'patient_attachments', 'clinics', 'medicines',
        'services', 'categories', 'insurance_companies', 'patient_insurance',
        'stock_movements', 'lab_results', 'lab_orders', 'vitals',
        'drug_interactions', 'prescription_templates', 'template_items',
        'icd10_codes', 'settings', 'audit_log',
      ];

      for (final table in allTables) {
        await _addColumnIfNotExists(db, table, 'updated_at', 'TEXT');
        await _addColumnIfNotExists(db, table, 'is_deleted', 'INTEGER DEFAULT 0');
      }

      final syncTables = [
        'clinics', 'users', 'patients', 'appointments',
        'waiting_queue', 'medical_records', 'prescriptions',
        'prescription_items', 'invoices', 'invoice_items', 'refunds',
        'inventory', 'shifts', 'lab_results', 'patient_attachments',
        'categories', 'services', 'insurance_companies',
      ];

      for (final table in syncTables) {
        await _addColumnIfNotExists(db, table, 'remote_id', 'TEXT');
        await _addColumnIfNotExists(db, table, 'sync_status', "TEXT DEFAULT 'pending'");
        await _addColumnIfNotExists(db, table, 'updated_at', 'TEXT');
        await _addColumnIfNotExists(db, table, 'deleted_at', 'TEXT');
        await _addColumnIfNotExists(db, table, 'sync_version', 'INTEGER DEFAULT 1');
        await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_${table}_remote_id ON $table(remote_id) WHERE remote_id IS NOT NULL');
      }

      await _addColumnIfNotExists(db, 'sync_queue', 'clinic_id', 'INTEGER DEFAULT 1');
      await _addColumnIfNotExists(db, 'sync_queue', 'remote_id', 'TEXT');
      await _addColumnIfNotExists(db, 'sync_queue', 'last_error', 'TEXT');
      await _addColumnIfNotExists(db, 'sync_queue', 'sync_status', "TEXT DEFAULT 'pending'");
      await _addColumnIfNotExists(db, 'sync_queue', 'synced_at', 'TEXT');

      await _addColumnIfNotExists(db, 'invoices', 'status', "TEXT DEFAULT 'paid'");
      await _addColumnIfNotExists(db, 'invoices', 'cash_amount', 'REAL DEFAULT 0.0');
      await _addColumnIfNotExists(db, 'invoices', 'card_amount', 'REAL DEFAULT 0.0');
      await _addColumnIfNotExists(db, 'refunds', 'clinic_id', 'INTEGER DEFAULT 1');
      await _addColumnIfNotExists(db, 'users', 'password_hash', 'TEXT');
      await _addColumnIfNotExists(db, 'patients', 'secondary_phone', 'TEXT');
      await _addColumnIfNotExists(db, 'patients', 'insurance_entity_name', 'TEXT');
      await _addColumnIfNotExists(db, 'patients', 'policy_number', 'TEXT');
      await _addColumnIfNotExists(db, 'patients', 'insurance_company_id', 'INTEGER');
      await _addColumnIfNotExists(db, 'patients', 'coverage_percentage', 'REAL DEFAULT 0');

      await _createSyncTables(db);
    } catch (e) {
      AppLogger.error('Failed ensuring required database columns exist: $e');
    }
  }

  Future<void> _createSyncTables(Database db) async {
    // 1. sync_metadata (بيانات المزامنة وتتبع الجهاز)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_metadata (
        table_name TEXT PRIMARY KEY,
        device_id TEXT,
        last_sync_at TEXT,
        last_pull_at TEXT,
        last_push_at TEXT,
        sync_version INTEGER DEFAULT 1
      )
    ''');

    // 2. sync_log (سجل عمليات المزامنة والتعارضات)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_time TEXT NOT NULL,
        table_name TEXT NOT NULL,
        operation TEXT NOT NULL,
        local_id INTEGER,
        remote_id TEXT,
        status TEXT NOT NULL,
        details TEXT,
        device_id TEXT
      )
    ''');
  }

  Future<void> _onUpgradeMigration(Database db, int oldVersion, int newVersion) async {
    // 1. Create new tables if not exists
    await _createTables(db);

    if (oldVersion < 17) {
      final tables = [
        'users', 'shifts', 'patients', 'appointments',
        'prescriptions', 'prescription_items', 'invoices', 'refunds',
        'inventory', 'patient_attachments', 'clinics', 'medicines',
        'services', 'categories', 'insurance_companies', 'patient_insurance',
        'stock_movements', 'lab_results', 'lab_orders', 'vitals',
        'drug_interactions', 'prescription_templates', 'template_items',
        'icd10_codes', 'settings', 'audit_log',
      ];

      for (var table in tables) {
        await _addColumnIfNotExists(db, table, 'clinic_id', 'INTEGER DEFAULT 1');
        await _addColumnIfNotExists(db, table, 'updated_at', 'TEXT');
        await _addColumnIfNotExists(db, table, 'is_deleted', 'INTEGER DEFAULT 0');
        await _addColumnIfNotExists(db, table, 'last_synced_at', 'TEXT');
      }
    }

    await _ensureRequiredColumnsExist(db);

    await _addColumnIfNotExists(db, 'users', 'password_hash', 'TEXT');
    await _addColumnIfNotExists(db, 'patients', 'secondary_phone', 'TEXT');
    await _addColumnIfNotExists(db, 'patients', 'insurance_entity_name', 'TEXT');
    await _addColumnIfNotExists(db, 'patients', 'policy_number', 'TEXT');
    await _addColumnIfNotExists(db, 'patients', 'insurance_company_id', 'INTEGER');
    await _addColumnIfNotExists(db, 'patients', 'coverage_percentage', 'REAL DEFAULT 0');

    // Create Indexes, Triggers, Sanitize Settings Keys & Convert Arabic DB values to English
    await _createIndexes(db);
    await _createTriggers(db);
    await sanitizeExtraneousSettingsKeys(db);
    await sanitizeArabicValuesToEnglish(db);
  }

  Future<void> sanitizeArabicValuesToEnglish(Database db) async {
    try {
      // Appointments status, type, priority
      await db.execute("UPDATE appointments SET status = 'waiting' WHERE status IN ('في الانتظار', 'منتظر')");
      await db.execute("UPDATE appointments SET status = 'in_progress' WHERE status IN ('جاري الكشف', 'في الكشف')");
      await db.execute("UPDATE appointments SET status = 'completed' WHERE status = 'مكتمل'");
      await db.execute("UPDATE appointments SET status = 'cancelled' WHERE status = 'ملغى'");
      await db.execute("UPDATE appointments SET status = 'no_show' WHERE status = 'لم يحضر'");
      
      await db.execute("UPDATE appointments SET type = 'new_consultation' WHERE type = 'كشف جديد'");
      await db.execute("UPDATE appointments SET type = 'follow_up' WHERE type IN ('إعادة / استشارة', 'استشارة')");
      await db.execute("UPDATE appointments SET type = 'lab_review' WHERE type IN ('متابعة نتيجه تحاليل', 'متابعة نتائج')");

      await db.execute("UPDATE appointments SET priority = 'normal' WHERE priority = 'عادي'");
      await db.execute("UPDATE appointments SET priority = 'urgent' WHERE priority = 'مستعجل'");
      await db.execute("UPDATE appointments SET priority = 'emergency' WHERE priority = 'حالة طارئة'");

      // Users role
      await db.execute("UPDATE users SET role = 'secretary' WHERE role IN ('receptionist', 'استقبال', 'سكرتير')");
      await db.execute("UPDATE users SET role = 'doctor' WHERE role IN ('طبيب', 'دكتور')");
      await db.execute("UPDATE users SET role = 'super_admin' WHERE role IN ('admin', 'مدير', 'سوبر أدمن')");

      // Invoices payment method
      await db.execute("UPDATE invoices SET payment_method = 'cash' WHERE payment_method IN ('نقدي (كاش)', 'كاش', 'نقدي')");
      await db.execute("UPDATE invoices SET payment_method = 'card' WHERE payment_method IN ('فيزا / كارت', 'فيزا', 'بطاقة')");
      await db.execute("UPDATE invoices SET payment_method = 'transfer' WHERE payment_method = 'تحويل بنكي'");
      await db.execute("UPDATE invoices SET payment_method = 'insurance' WHERE payment_method IN ('تأمين صحي', 'تأمين')");

      // Patients demographics
      await db.execute("UPDATE patients SET gender = 'male' WHERE gender = 'ذكر'");
      await db.execute("UPDATE patients SET gender = 'female' WHERE gender = 'أنثى'");
      await db.execute("UPDATE patients SET female_status = 'normal' WHERE female_status = 'طبيعي'");
      await db.execute("UPDATE patients SET female_status = 'pregnant' WHERE female_status = 'حامل'");
      await db.execute("UPDATE patients SET female_status = 'lactating' WHERE female_status = 'مرضع'");
      await db.execute("UPDATE patients SET contract_entity = 'cash' WHERE contract_entity IN ('نقدي (خاص)', 'نقدي')");

      // Lab results status
      await db.execute("UPDATE lab_results SET status = 'normal' WHERE status = 'طبيعي'");
      await db.execute("UPDATE lab_results SET status = 'high' WHERE status = 'مرتفع'");
      await db.execute("UPDATE lab_results SET status = 'low' WHERE status = 'منخفض'");
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

  Future<void> _ensureOwnerAccountExists(Database db) async {
    try {
      final existingUser = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: ['mo_hassan'],
      );

      if (existingUser.isNotEmpty) {
        AppLogger.info('Owner account (mo_hassan) already exists. Skipping creation.');
        return;
      }

      final nowStr = DateTime.now().toIso8601String();
      final passwordHash = PasswordHasher.hashPassword('123456');

      await db.insert('users', {
        'clinic_id': 1,
        'username': 'mo_hassan',
        'password': '123456',
        'password_hash': passwordHash,
        'full_name': 'م. محمد حسن (مالك التطبيق)',
        'role': 'super_admin',
        'branch': 'جميع الفروع (سوبر أدمن)',
        'permissions_json': '["*"]',
        'is_active': 1,
        'created_at': nowStr,
        'updated_at': nowStr,
        'is_deleted': 0,
      });

      AppLogger.info('Successfully created Owner account (mo_hassan) with super_admin permissions.');
    } catch (e) {
      AppLogger.error('Failed to ensure owner account existence', e);
    }
  }

  Future<void> _createDB(Database db, int version) async {
    AppLogger.info('Creating SQLite tables and indexes...');
    await _createTables(db);
    await _createIndexes(db);
    await _createTriggers(db);
    await _seedInitialData(db);
    await _ensureOwnerAccountExists(db);
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
        secondary_phone TEXT,
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
        insurance_entity_name TEXT,
        policy_number TEXT,
        insurance_company_id INTEGER,
        coverage_percentage REAL DEFAULT 0,
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
        cash_amount REAL DEFAULT 0.0,
        card_amount REAL DEFAULT 0.0,
        payment_method TEXT NOT NULL,
        status TEXT DEFAULT 'paid',
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

    // 8.1 Refunds Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS refunds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        patient_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        shift_id INTEGER NOT NULL,
        refund_amount REAL NOT NULL,
        reason TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE,
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

    // 18. Sync Queue Table (طابور المزامنة الموحد)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER DEFAULT 1,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        remote_id TEXT,
        operation TEXT NOT NULL,
        payload TEXT,
        sync_status TEXT DEFAULT 'pending',
        retry_count INTEGER DEFAULT 0,
        last_error TEXT,
        created_at TEXT,
        synced_at TEXT
      )
    ''');

    // 18.1 Sync System Tables (Metadata, Log)
    await _createSyncTables(db);

    // 18.1 Sync Outbox Table (Outbox Pattern)
    await db.execute('''
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

    // 25. Categories Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER DEFAULT 1,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE
      )
    ''');



    // 27. Stock Movements Audit Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER DEFAULT 1,
        item_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        reason TEXT,
        reference_no TEXT,
        user_id INTEGER,
        created_at TEXT,
        FOREIGN KEY (item_id) REFERENCES inventory(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // 28. Waiting Queue Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS waiting_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER DEFAULT 1,
        appointment_id INTEGER,
        patient_id INTEGER NOT NULL,
        queue_number INTEGER,
        status TEXT DEFAULT 'waiting',
        entered_at TEXT,
        created_at TEXT,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE,
        FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE
      )
    ''');

    // 29. Medical Records Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS medical_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER DEFAULT 1,
        patient_id INTEGER NOT NULL,
        doctor_id INTEGER NOT NULL,
        appointment_id INTEGER,
        complaint TEXT,
        diagnosis TEXT,
        treatment_plan TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE,
        FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE,
        FOREIGN KEY (doctor_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // 30. Invoice Items Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER DEFAULT 1,
        invoice_id INTEGER NOT NULL,
        service_name TEXT NOT NULL,
        quantity INTEGER DEFAULT 1,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        created_at TEXT,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
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

  Future<void> _createTriggers(Database db) async {
    AppLogger.info('Creating database triggers for updated_at timestamps...');
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
        CREATE TRIGGER IF NOT EXISTS update_${table}_updated_at
        AFTER UPDATE ON $table
        FOR EACH ROW
        WHEN (OLD.updated_at IS NULL OR OLD.updated_at = NEW.updated_at)
        BEGIN
          UPDATE $table SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
        END;
      ''');
    }
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
        'categories',
        'stock_movements',
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
    AppLogger.info('Initializing SQLite schema with default clinic, categories, and services.');
    final nowStr = DateTime.now().toIso8601String();

    // 1. Seed Default Clinic if empty (Required for FK constraints)
    final clinicCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM clinics');
    final clinicCount = clinicCountRes.isNotEmpty ? (clinicCountRes.first['count'] as int? ?? 0) : 0;
    if (clinicCount == 0) {
      await db.insert('clinics', {
        'id': 1,
        'name': 'العيادة الرئيسية',
        'currency': 'EGP',
        'subscription_plan': 'starter',
        'is_active': 1,
        'created_at': nowStr,
        'updated_at': nowStr,
      });
    }

    // 2. Seed Default Categories if empty
    final catCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM categories');
    final catCount = catCountRes.isNotEmpty ? (catCountRes.first['count'] as int? ?? 0) : 0;
    if (catCount == 0) {
      final initialCategories = [
        {'name': 'كواشف ومحاليل كيمياء', 'type': 'inventory'},
        {'name': 'أدوات سحب وأنابيب', 'type': 'inventory'},
        {'name': 'مستهلكات وقاية وتعقيم', 'type': 'inventory'},
        {'name': 'أدوية ومستلزمات عامة', 'type': 'inventory'},
        {'name': 'كشف عيادة', 'type': 'service'},
        {'name': 'استشارة ومتابعة', 'type': 'service'},
        {'name': 'أشعة سينية / CT', 'type': 'attachment'},
        {'name': 'تقرير معملي خارجي', 'type': 'attachment'},
        {'name': 'روشتة مصورة', 'type': 'attachment'},
      ];
      for (var cat in initialCategories) {
        await db.insert('categories', {
          'clinic_id': 1,
          'name': cat['name'],
          'type': cat['type'],
          'is_active': 1,
          'created_at': nowStr,
        });
      }
    }

    // 5. Seed Default Services if empty
    final serviceCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM services');
    final serviceCount = serviceCountRes.isNotEmpty ? (serviceCountRes.first['count'] as int? ?? 0) : 0;
    if (serviceCount == 0) {
      final initialServices = [
        {'name': 'كشف جديد', 'category': 'كشف عيادة', 'price': 200.0, 'duration_minutes': 20},
        {'name': 'إعادة / استشارة', 'category': 'استشارة ومتابعة', 'price': 50.0, 'duration_minutes': 10},
        {'name': 'متابعة نتائج تحاليل', 'category': 'استشارة ومتابعة', 'price': 0.0, 'duration_minutes': 10},
      ];
      for (var srv in initialServices) {
        await db.insert('services', {
          'clinic_id': 1,
          'name': srv['name'],
          'category': srv['category'],
          'price': srv['price'],
          'duration_minutes': srv['duration_minutes'],
          'is_active': 1,
          'created_at': nowStr,
        });
      }
    }

    AppLogger.info('Database seeded successfully with initial clinic, settings, users, categories, and services.');
  }

  Future<void> _addColumnIfNotExists(Database db, String tableName, String columnName, String columnDef) async {
    try {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      );
      if (tables.isEmpty) return;

      final info = await db.rawQuery("PRAGMA table_info($tableName)");
      final exists = info.any((col) => col['name'] == columnName);
      if (!exists) {
        await db.execute('ALTER TABLE $tableName ADD COLUMN $columnName $columnDef');
      }
    } catch (e) {
      AppLogger.error('Could not add column $columnName to $tableName: $e');
    }
  }

  static String? _cachedDeviceId;

  static Future<String> getDeviceId(DatabaseExecutor executor) async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    try {
      final res = await executor.query('settings', where: 'key = ?', whereArgs: ['device_id']);
      if (res.isNotEmpty && res.first['value'] != null) {
        _cachedDeviceId = res.first['value'] as String;
        return _cachedDeviceId!;
      }
    } catch (_) {}

    final newId = 'device_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecondsSinceEpoch % 9000))}';
    try {
      final clinicCheck = await executor.query('clinics', where: 'id = ?', whereArgs: [1]);
      if (clinicCheck.isEmpty) {
        await executor.insert('clinics', {
          'id': 1,
          'name': 'العيادة الرئيسية',
          'currency': 'EGP',
          'subscription_plan': 'starter',
          'is_active': 1,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      await executor.insert('settings', {
        'clinic_id': 1,
        'key': 'device_id',
        'value': newId,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      AppLogger.info('Could not store device_id in settings table: $e');
    }
    _cachedDeviceId = newId;
    return newId;
  }

  Future<int> insertOutboxEvent(
    DatabaseExecutor executor, {
    required int clinicId,
    int? userId,
    required String tableName,
    required int recordId,
    required String operation,
    Map<String, dynamic>? payload,
    String? deviceId,
  }) async {
    final nowStr = DateTime.now().toIso8601String();
    final dId = deviceId ?? await getDeviceId(executor);

    return await executor.insert('sync_outbox', {
      'device_id': dId,
      'clinic_id': clinicId,
      'user_id': userId,
      'table_name': tableName,
      'record_id': recordId,
      'operation': operation,
      'payload': payload != null ? jsonEncode(payload) : null,
      'status': 'pending',
      'retry_count': 0,
      'error_message': null,
      'created_at': nowStr,
      'synced_at': null,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingOutboxEvents({int limit = 50}) async {
    final db = await database;
    return await db.query(
      'sync_outbox',
      where: "status = 'pending' AND retry_count < 10",
      orderBy: 'id ASC',
      limit: limit,
    );
  }

  Future<void> markOutboxEventSynced(int outboxId) async {
    final db = await database;
    final nowStr = DateTime.now().toIso8601String();
    await db.update(
      'sync_outbox',
      {
        'status': 'synced',
        'synced_at': nowStr,
        'error_message': null,
      },
      where: 'id = ?',
      whereArgs: [outboxId],
    );
  }

  Future<void> markOutboxEventFailed(int outboxId, String errorMessage) async {
    final db = await database;
    final res = await db.query('sync_outbox', columns: ['retry_count'], where: 'id = ?', whereArgs: [outboxId]);
    if (res.isEmpty) return;

    final currentRetry = res.first['retry_count'] as int? ?? 0;
    final newRetry = currentRetry + 1;
    final isMaxRetries = newRetry >= 10;
    final newStatus = isMaxRetries ? 'failed' : 'pending';

    await db.update(
      'sync_outbox',
      {
        'retry_count': newRetry,
        'error_message': errorMessage,
        'status': newStatus,
      },
      where: 'id = ?',
      whereArgs: [outboxId],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Offline Sync Queue, Metadata & Audit Logging Helpers
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> addToSyncQueue({
    required String tableName,
    required int recordId,
    String? remoteId,
    required String operation,
    Map<String, dynamic>? payload,
    int clinicId = 1,
    DatabaseExecutor? executor,
  }) async {
    final exec = executor ?? await database;
    final nowStr = DateTime.now().toIso8601String();
    return await exec.insert('sync_queue', {
      'clinic_id': clinicId,
      'table_name': tableName,
      'record_id': recordId,
      'remote_id': remoteId,
      'operation': operation,
      'payload': payload != null ? jsonEncode(payload) : null,
      'created_at': nowStr,
      'retry_count': 0,
      'last_error': null,
      'sync_status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSyncQueue({int limit = 50}) async {
    final db = await database;
    return await db.query(
      'sync_queue',
      where: "sync_status = 'pending' AND retry_count < 5",
      orderBy: 'id ASC',
      limit: limit,
    );
  }

  Future<void> markSyncQueueItemSynced(int id) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {
        'sync_status': 'synced',
        'last_error': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markSyncQueueItemFailed(int id, String error, int retryCount) async {
    final db = await database;
    final isMax = retryCount >= 5;
    await db.update(
      'sync_queue',
      {
        'retry_count': retryCount,
        'last_error': error,
        'sync_status': isMax ? 'failed' : 'pending',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> purgeOldSyncedQueueItems({int days = 7}) async {
    final db = await database;
    await db.rawDelete(
      "DELETE FROM sync_queue WHERE sync_status = 'synced' AND julianday('now') - julianday(created_at) > ?",
      [days],
    );
  }

  Future<int> insertSyncLog({
    required String tableName,
    required String operation,
    int? localId,
    String? remoteId,
    required String status,
    String? details,
    String? deviceId,
  }) async {
    final db = await database;
    final nowStr = DateTime.now().toIso8601String();
    final dId = deviceId ?? await getOrCreateDeviceId();
    return await db.insert('sync_log', {
      'sync_time': nowStr,
      'table_name': tableName,
      'operation': operation,
      'local_id': localId,
      'remote_id': remoteId,
      'status': status,
      'details': details,
      'device_id': dId,
    });
  }

  Future<Map<String, dynamic>?> getSyncMetadata(String tableName) async {
    final db = await database;
    final res = await db.query(
      'sync_metadata',
      where: 'table_name = ?',
      whereArgs: [tableName],
    );
    if (res.isNotEmpty) {
      return res.first;
    }
    return null;
  }

  Future<void> setSyncMetadata(
    String tableName, {
    String? lastSyncAt,
    String? lastPullAt,
    String? lastPushAt,
    String? deviceId,
  }) async {
    final db = await database;
    final Map<String, dynamic> values = {
      'table_name': tableName,
    };
    if (lastSyncAt != null) values['last_sync_at'] = lastSyncAt;
    if (lastPullAt != null) values['last_pull_at'] = lastPullAt;
    if (lastPushAt != null) values['last_push_at'] = lastPushAt;
    if (deviceId != null) values['device_id'] = deviceId;

    await db.insert(
      'sync_metadata',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getPendingSyncQueueCount() async {
    final db = await database;
    final res = await db.rawQuery("SELECT COUNT(*) as cnt FROM sync_queue WHERE sync_status = 'pending'");
    if (res.isEmpty) return 0;
    return (res.first['cnt'] as int?) ?? 0;
  }

  Future<int> getFailedSyncQueueCount() async {
    final db = await database;
    final res = await db.rawQuery("SELECT COUNT(*) as cnt FROM sync_queue WHERE sync_status = 'failed' OR retry_count >= 5");
    if (res.isEmpty) return 0;
    return (res.first['cnt'] as int?) ?? 0;
  }

  Future<int> getSuccessfulSyncLogsCount() async {
    final db = await database;
    final res = await db.rawQuery("SELECT COUNT(*) as cnt FROM sync_log WHERE status = 'success'");
    if (res.isEmpty) return 0;
    return (res.first['cnt'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getRecentSyncLogs({int limit = 50}) async {
    final db = await database;
    return await db.query(
      'sync_log',
      orderBy: 'sync_time DESC, id DESC',
      limit: limit,
    );
  }

  Future<int> retryFailedSyncQueueItems() async {
    final db = await database;
    return await db.update(
      'sync_queue',
      {
        'retry_count': 0,
        'sync_status': 'pending',
        'last_error': null,
      },
      where: "sync_status = 'failed' OR retry_count >= 5",
    );
  }

  Future<void> updateRecordRemoteId(String tableName, int localId, String remoteId) async {
    final db = await database;
    try {
      final info = await db.rawQuery("PRAGMA table_info($tableName)");
      final hasRemoteId = info.any((col) => col['name'] == 'remote_id');
      if (hasRemoteId) {
        final Map<String, dynamic> updateValues = {'remote_id': remoteId};
        if (info.any((col) => col['name'] == 'sync_status')) {
          updateValues['sync_status'] = 'synced';
        }
        if (info.any((col) => col['name'] == 'updated_at')) {
          updateValues['updated_at'] = DateTime.now().toUtc().toIso8601String();
        }
        await db.update(
          tableName,
          updateValues,
          where: 'id = ?',
          whereArgs: [localId],
        );
      }
    } catch (_) {}
  }

  Future<String?> getLocalRecordRemoteId(String tableName, int localId) async {
    final db = await database;
    try {
      final info = await db.rawQuery("PRAGMA table_info($tableName)");
      final hasRemoteId = info.any((col) => col['name'] == 'remote_id');
      if (hasRemoteId) {
        final res = await db.query(
          tableName,
          columns: ['remote_id'],
          where: 'id = ?',
          whereArgs: [localId],
        );
        if (res.isNotEmpty && res.first['remote_id'] != null) {
          return res.first['remote_id'] as String;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String> getOrCreateDeviceId() async {
    final db = await database;
    return await getDeviceId(db);
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
  }
}
