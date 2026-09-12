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
      version: 5,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        AppLogger.info('Upgrading database version from $oldVersion to $newVersion...');
        await db.execute('DROP TABLE IF EXISTS sync_queue');
        await db.execute('DROP TABLE IF EXISTS patient_insurance');
        await db.execute('DROP TABLE IF EXISTS insurance_companies');
        await db.execute('DROP TABLE IF EXISTS audit_log');
        await db.execute('DROP TABLE IF EXISTS settings');
        await db.execute('DROP TABLE IF EXISTS services');
        await db.execute('DROP TABLE IF EXISTS medicines');
        await db.execute('DROP TABLE IF EXISTS clinics');
        await db.execute('DROP TABLE IF EXISTS patient_attachments');
        await db.execute('DROP TABLE IF EXISTS lab_results');
        await db.execute('DROP TABLE IF EXISTS prescription_items');
        await db.execute('DROP TABLE IF EXISTS prescriptions');
        await db.execute('DROP TABLE IF EXISTS invoices');
        await db.execute('DROP TABLE IF EXISTS appointments');
        await db.execute('DROP TABLE IF EXISTS shifts');
        await db.execute('DROP TABLE IF EXISTS inventory');
        await db.execute('DROP TABLE IF EXISTS patients');
        await db.execute('DROP TABLE IF EXISTS users');
        await _createDB(db, newVersion);
      },
    );

    await _checkAndSeedUsersIfEmpty(db);
    return db;
  }

  Future<void> _checkAndSeedUsersIfEmpty(Database db) async {
    final countRes = await db.rawQuery('SELECT COUNT(*) as count FROM users');
    final count = countRes.isNotEmpty ? (countRes.first['count'] as int? ?? 0) : 0;
    if (count == 0) {
      await _seedInitialData(db);
    }
  }

  Future<void> _createDB(Database db, int version) async {
    AppLogger.info('Creating SQLite tables...');

    // 1. Users Table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        full_name TEXT NOT NULL,
        role TEXT NOT NULL,
        branch TEXT DEFAULT 'جميع الفروع (سوبر أدمن)',
        permissions_json TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 2. Shifts Table
    await db.execute('''
      CREATE TABLE shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        starting_cash REAL NOT NULL,
        ending_cash REAL DEFAULT 0.0,
        is_closed INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 3. Patients Table
    await db.execute('''
      CREATE TABLE patients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
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
        created_at TEXT NOT NULL
      )
    ''');

    // 4. Appointments Table
    await db.execute('''
      CREATE TABLE appointments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
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
        FOREIGN KEY (patient_id) REFERENCES patients (id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (shift_id) REFERENCES shifts (id) ON DELETE CASCADE
      )
    ''');

    // 5. Prescriptions Table
    await db.execute('''
      CREATE TABLE prescriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        appointment_id INTEGER,
        patient_id INTEGER NOT NULL,
        doctor_id INTEGER NOT NULL,
        diagnosis TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (patient_id) REFERENCES patients (id) ON DELETE CASCADE,
        FOREIGN KEY (doctor_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 6. Prescription Items Table
    await db.execute('''
      CREATE TABLE prescription_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        prescription_id INTEGER NOT NULL,
        medicine_name TEXT NOT NULL,
        dosage TEXT NOT NULL,
        frequency TEXT NOT NULL,
        duration TEXT NOT NULL,
        FOREIGN KEY (prescription_id) REFERENCES prescriptions (id) ON DELETE CASCADE
      )
    ''');

    // 7. Invoices Table
    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        shift_id INTEGER NOT NULL,
        total_amount REAL NOT NULL,
        discount REAL DEFAULT 0.0,
        paid_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (patient_id) REFERENCES patients (id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (shift_id) REFERENCES shifts (id) ON DELETE CASCADE
      )
    ''');

    // 8. Inventory Table
    await db.execute('''
      CREATE TABLE inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
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
        supplier_name TEXT
      )
    ''');

    // 9. Lab Results Table
    await db.execute('''
      CREATE TABLE lab_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id INTEGER NOT NULL,
        test_name TEXT NOT NULL,
        test_date TEXT NOT NULL,
        measured_value TEXT NOT NULL,
        unit TEXT NOT NULL,
        reference_range TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (patient_id) REFERENCES patients (id) ON DELETE CASCADE
      )
    ''');

    // 10. Patient Attachments Table
    await db.execute('''
      CREATE TABLE patient_attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id INTEGER NOT NULL,
        file_name TEXT NOT NULL,
        file_type TEXT NOT NULL,
        file_path TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (patient_id) REFERENCES patients (id) ON DELETE CASCADE
      )
    ''');

    // 11. Clinics Table (Multi-tenant)
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

    // 12. Medicines Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS medicines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER,
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
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE
      )
    ''');

    // 13. Services Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS services (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER,
        name TEXT NOT NULL,
        category TEXT,
        price REAL NOT NULL,
        duration_minutes INTEGER,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE
      )
    ''');

    // 14. Settings Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER,
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
        clinic_id INTEGER,
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
        clinic_id INTEGER,
        name TEXT NOT NULL,
        contact_person TEXT,
        phone TEXT,
        email TEXT,
        discount_percentage REAL,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT,
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
        FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE,
        FOREIGN KEY (insurance_company_id) REFERENCES insurance_companies(id) ON DELETE CASCADE
      )
    ''');

    // 18. Sync Queue Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clinic_id INTEGER,
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


    // Seed default admin and initial sample data
    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    AppLogger.info('Seeding initial system users...');

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

    // 1. Super Admin User
    await db.insert('users', {
      'username': 'mo_hassan',
      'password': '123456',
      'full_name': 'mohamed hassan',
      'role': 'admin',
      'branch': 'جميع الفروع (سوبر أدمن)',
      'permissions_json': allPermissions,
      'is_active': 1,
    });

    // 2. Doctor User
    await db.insert('users', {
      'username': 'dr_hassan',
      'password': '123456',
      'full_name': 'د. محمد حسن (طبيب معالج)',
      'role': 'doctor',
      'branch': 'فرع السلام (الرئيسي)',
      'permissions_json': doctorPermissions,
      'is_active': 1,
    });

    AppLogger.info('Database seeded successfully with initial users mo_hassan and dr_hassan.');
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
  }
}
