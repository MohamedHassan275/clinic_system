import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/common/error_handler/failure.dart';
import '../../../../core/database/database_helper.dart';

import '../../../../core/enums/appointment_enums.dart';

abstract class ClinicRepo {
  // Dashboard
  Future<Either<Failure, Map<String, dynamic>>> getDashboardStats();

  // Appointments
  Future<Either<Failure, List<Map<String, dynamic>>>> getAppointments({String? date});
  Future<Either<Failure, int>> addAppointment(Map<String, dynamic> appointment);
  Future<Either<Failure, void>> updateAppointmentStatus(int id, String status);
  Future<Either<Failure, void>> updateAppointment(Map<String, dynamic> appointment);
  Future<Either<Failure, void>> rescheduleAppointment(int id, String newDate, String newTimeSlot);

  // Waiting Room
  Future<Either<Failure, List<Map<String, dynamic>>>> getWaitingRoomQueue();

  // EMR & Patients
  Future<Either<Failure, List<Map<String, dynamic>>>> getPatients({String? query});
  Future<Either<Failure, int>> addPatient(Map<String, dynamic> patient);
  Future<Either<Failure, void>> updatePatient(Map<String, dynamic> patient);
  Future<Either<Failure, void>> deletePatient(int patientId);
  Future<Either<Failure, Map<String, dynamic>>> getPatientFullMedicalRecord(int patientId);

  // Prescriptions
  Future<Either<Failure, int>> addPrescription({
    required Map<String, dynamic> prescription,
    required List<Map<String, dynamic>> items,
  });

  // Invoices & Billing
  Future<Either<Failure, List<Map<String, dynamic>>>> getInvoices();
  Future<Either<Failure, int>> createInvoice(Map<String, dynamic> invoice);
  Future<Either<Failure, void>> refundInvoice({
    required int invoiceId,
    required double refundAmount,
    required String reason,
    required int userId,
    required int shiftId,
    required int patientId,
  });

  // Inventory
  Future<Either<Failure, List<Map<String, dynamic>>>> getInventory();
  Future<Either<Failure, int>> addInventoryItem(Map<String, dynamic> item);
  Future<Either<Failure, void>> updateInventoryItem(int id, int qty);
  Future<Either<Failure, void>> deleteInventoryItem(int id);

  // Reports
  Future<Either<Failure, Map<String, dynamic>>> getReports();

  // EMR & Lab Extras
  Future<Either<Failure, int>> addLabResult(Map<String, dynamic> result);
  Future<Either<Failure, int>> addPatientAttachment(Map<String, dynamic> attachment);

  // Staff & Settings
  Future<Either<Failure, List<Map<String, dynamic>>>> getUsers();
  Future<Either<Failure, int>> addUser(Map<String, dynamic> user);
  Future<Either<Failure, void>> updateUser(Map<String, dynamic> user);
  Future<Either<Failure, void>> updateUserPermissions(int userId, List<String> permissions);
  Future<Either<Failure, void>> deleteUser(int userId);
  Future<Either<Failure, Map<String, dynamic>>> getClinicInfo();
  Future<Either<Failure, void>> updateClinicInfo(Map<String, dynamic> clinicInfo);
}

class ClinicRepoImpl implements ClinicRepo {
  @override
  Future<Either<Failure, Map<String, dynamic>>> getDashboardStats() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      // Today's appointments count
      final apptRes = await db.rawQuery(
        'SELECT COUNT(*) as count FROM appointments WHERE appointment_date LIKE ?',
        ['$todayStr%'],
      );
      final todayAppointments = Sqflite.firstIntValue(apptRes) ?? 0;

      // Today's waiting patients count
      final waitRes = await db.rawQuery(
        "SELECT COUNT(*) as count FROM appointments WHERE status = 'منتظر'",
      );
      final waitingCount = Sqflite.firstIntValue(waitRes) ?? 0;

      // Total Patients
      final patRes = await db.rawQuery('SELECT COUNT(*) as count FROM patients');
      final totalPatients = Sqflite.firstIntValue(patRes) ?? 0;

      // Today's Revenue
      final revRes = await db.rawQuery(
        'SELECT SUM(paid_amount) as total FROM invoices WHERE created_at LIKE ?',
        ['$todayStr%'],
      );
      final double todayRevenue = (revRes.first['total'] as num?)?.toDouble() ?? 0.0;

      return Right({
        'todayAppointments': todayAppointments,
        'waitingCount': waitingCount,
        'totalPatients': totalPatients,
        'todayRevenue': todayRevenue,
      });
    } catch (e) {
      return Left(Failure(500, 'فشل جلب إحصائيات لوحة التحكم: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getAppointments({String? date}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      String query = '''
        SELECT a.*, p.name as patient_name, p.phone as patient_phone, u.full_name as doctor_name
        FROM appointments a
        JOIN patients p ON a.patient_id = p.id
        JOIN users u ON a.user_id = u.id
      ''';
      List<dynamic> args = [];
      if (date != null && date.isNotEmpty) {
        query += ' WHERE a.appointment_date LIKE ?';
        args.add('$date%');
      }
      query += ' ORDER BY a.id DESC';

      final res = await db.rawQuery(query, args);
      return Right(res);
    } catch (e) {
      return Left(Failure(500, 'فشل جلب المواعيد: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> addAppointment(Map<String, dynamic> appointment) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final id = await db.insert('appointments', appointment);
      return Right(id);
    } catch (e) {
      return Left(Failure(500, 'فشل إضافة الموعد: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateAppointmentStatus(int id, String status) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final dbStatus = AppointmentStatus.fromString(status).dbValue;
      await db.update('appointments', {'status': dbStatus}, where: 'id = ?', whereArgs: [id]);
      return const Right(null);
    } catch (e) {
      return Left(Failure(500, 'فشل تحديث حالة الموعد: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateAppointment(Map<String, dynamic> appointment) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final int id = appointment['id'];
      await db.update('appointments', appointment, where: 'id = ?', whereArgs: [id]);
      return const Right(null);
    } catch (e) {
      return Left(Failure(500, 'فشل تحديث بيانات الموعد: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> rescheduleAppointment(int id, String newDate, String newTimeSlot) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'appointments',
        {
          'appointment_date': newDate,
          'time_slot': newTimeSlot,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return const Right(null);
    } catch (e) {
      return Left(Failure(500, 'فشل إعادة جدولة الموعد: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getWaitingRoomQueue() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db.rawQuery('''
        SELECT a.*, p.name as patient_name, p.phone as patient_phone
        FROM appointments a
        JOIN patients p ON a.patient_id = p.id
        WHERE a.status IN ('waiting', 'in_progress', 'منتظر', 'في الكشف', 'في الانتظار', 'جاري الكشف')
        ORDER BY a.id ASC
      ''');
      return Right(res);
    } catch (e) {
      return Left(Failure(500, 'فشل جلب قائمة الانتظار: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getPatients({String? query}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      String sql = 'SELECT * FROM patients';
      List<dynamic> args = [];
      if (query != null && query.isNotEmpty) {
        sql += ' WHERE name LIKE ? OR phone LIKE ? OR national_id LIKE ? OR contract_entity LIKE ?';
        args = ['%$query%', '%$query%', '%$query%', '%$query%'];
      }
      sql += ' ORDER BY id DESC';
      final res = await db.rawQuery(sql, args);
      return Right(res);
    } catch (e) {
      return Left(Failure(500, 'فشل استعلام المرضى: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> addPatient(Map<String, dynamic> patient) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final id = await db.insert('patients', patient);
      return Right(id);
    } catch (e) {
      return Left(Failure(500, 'فشل إضافة المريض: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updatePatient(Map<String, dynamic> patient) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final int id = patient['id'];
      await db.update('patients', patient, where: 'id = ?', whereArgs: [id]);
      return const Right(null);
    } catch (e) {
      return Left(Failure(500, 'فشل تحديث بيانات المريض: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deletePatient(int patientId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('patients', where: 'id = ?', whereArgs: [patientId]);
      return const Right(null);
    } catch (e) {
      return Left(Failure(500, 'فشل حذف سجل المريض: $e'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getPatientFullMedicalRecord(int patientId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final pat = await db.query('patients', where: 'id = ?', whereArgs: [patientId]);
      final appts = await db.query('appointments', where: 'patient_id = ?', whereArgs: [patientId]);
      final prescs = await db.query('prescriptions', where: 'patient_id = ?', whereArgs: [patientId]);
      final labs = await db.query('lab_results', where: 'patient_id = ?', whereArgs: [patientId], orderBy: 'id DESC');
      final attach = await db.query('patient_attachments', where: 'patient_id = ?', whereArgs: [patientId], orderBy: 'id DESC');

      return Right({
        'patient': pat.isNotEmpty ? pat.first : null,
        'appointments': appts,
        'prescriptions': prescs,
        'lab_results': labs,
        'attachments': attach,
      });
    } catch (e) {
      return Left(Failure(500, 'فشل جلب الملف الطبي للمريض: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> addPrescription({
    required Map<String, dynamic> prescription,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      int prescId = 0;
      await db.transaction((txn) async {
        prescId = await txn.insert('prescriptions', prescription);
        for (var item in items) {
          await txn.insert('prescription_items', {
            ...item,
            'prescription_id': prescId,
          });
        }
      });
      return Right(prescId);
    } catch (e) {
      return Left(Failure(500, 'فشل إدراج الروشتة الإلكترونية: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getInvoices() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db.rawQuery('''
        SELECT i.*, p.name as patient_name, p.phone as patient_phone, u.full_name as creator_name,
               COALESCE((SELECT SUM(refund_amount) FROM refunds WHERE invoice_id = i.id), 0.0) as refunded_amount
        FROM invoices i
        JOIN patients p ON i.patient_id = p.id
        JOIN users u ON i.user_id = u.id
        ORDER BY i.id DESC
      ''');
      return Right(res);
    } catch (e) {
      return Left(Failure(500, 'فشل استعلام الفواتير: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> createInvoice(Map<String, dynamic> invoice) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final id = await db.insert('invoices', invoice);
      return Right(id);
    } catch (e) {
      return Left(Failure(500, 'فشل إنشاء الفاتورة: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> refundInvoice({
    required int invoiceId,
    required double refundAmount,
    required String reason,
    required int userId,
    required int shiftId,
    required int patientId,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final nowStr = DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ');

      await db.transaction((txn) async {
        await txn.insert('refunds', {
          'invoice_id': invoiceId,
          'patient_id': patientId,
          'user_id': userId,
          'shift_id': shiftId,
          'refund_amount': refundAmount,
          'reason': reason,
          'created_at': nowStr,
        });

        final invRes = await txn.query('invoices', where: 'id = ?', whereArgs: [invoiceId]);
        if (invRes.isNotEmpty) {
          final originalPaid = (invRes.first['paid_amount'] as num?)?.toDouble() ?? 0.0;
          final refRes = await txn.rawQuery('SELECT SUM(refund_amount) as total FROM refunds WHERE invoice_id = ?', [invoiceId]);
          final totalRefunded = (refRes.first['total'] as num?)?.toDouble() ?? 0.0;

          final newStatus = (totalRefunded >= originalPaid) ? 'refunded' : 'partially_refunded';
          await txn.update(
            'invoices',
            {'status': newStatus, 'updated_at': nowStr},
            where: 'id = ?',
            whereArgs: [invoiceId],
          );
        }
      });
      return const Right(null);
    } catch (e) {
      return Left(Failure(500, 'فشل استرجاع الفاتورة: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getInventory() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db.query('inventory', orderBy: 'id DESC');
      return Right(res);
    } catch (e) {
      return Left(Failure(500, 'فشل جلب مستلزمات المخزن: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> addInventoryItem(Map<String, dynamic> item) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final id = await db.insert('inventory', item);
      return Right(id);
    } catch (e) {
      return Left(Failure(500, 'فشل إضافة مستلزم للمخزن: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateInventoryItem(int id, int qty) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update('inventory', {'quantity': qty}, where: 'id = ?', whereArgs: [id]);
      return const Right(null);
    } catch (e) {
      return Left(Failure(500, 'فشل تحديث كمية المستلزم: $e'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getReports() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final revRes = await db.rawQuery('SELECT SUM(paid_amount) as totalRevenue FROM invoices');
      final apptRes = await db.rawQuery('SELECT COUNT(*) as totalAppts FROM appointments');
      final patRes = await db.rawQuery('SELECT COUNT(*) as totalPatients FROM patients');
      final lowStockRes = await db.rawQuery('SELECT COUNT(*) as lowStock FROM inventory WHERE quantity <= min_threshold');

      return Right({
        'totalRevenue': (revRes.first['totalRevenue'] as num?)?.toDouble() ?? 0.0,
        'totalAppointments': Sqflite.firstIntValue(apptRes) ?? 0,
        'totalPatients': Sqflite.firstIntValue(patRes) ?? 0,
        'lowStockItems': Sqflite.firstIntValue(lowStockRes) ?? 0,
      });
    } catch (e) {
      return Left(Failure(500, 'فشل إعداد التقارير: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getUsers() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db.query('users', orderBy: 'id ASC');
      return Right(res);
    } catch (e) {
      return Left(Failure(500, 'فشل جلب المستخدمين: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> addUser(Map<String, dynamic> user) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final id = await db.insert('users', user);
      return Right(id);
    } catch (e) {
      return Left(Failure(500, 'فشل إضافة المستخدم: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateUser(Map<String, dynamic> user) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final int id = user['id'];
      await db.update('users', user, where: 'id = ?', whereArgs: [id]);
      return const Right(null);
    } catch (e) {
      return Left(Failure(500, 'فشل تعديل بيانات المستخدم: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateUserPermissions(int userId, List<String> permissions) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final permsJson = jsonEncode(permissions);
      await db.update('users', {'permissions_json': permsJson}, where: 'id = ?', whereArgs: [userId]);
      return const Right(null);
    } catch (e) {
      return Left(Failure(500, 'فشل تحديث صلاحيات المستخدم: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteInventoryItem(int id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('inventory', where: 'id = ?', whereArgs: [id]);
      return const Right(null);
    } catch (e) {
      return Left(Failure(500, 'فشل حذف صنف المخزن: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> addLabResult(Map<String, dynamic> result) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final id = await db.insert('lab_results', result);
      return Right(id);
    } catch (e) {
      return Left(Failure(500, 'فشل إدراج نتيجة التحليل: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> addPatientAttachment(Map<String, dynamic> attachment) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final id = await db.insert('patient_attachments', attachment);
      return Right(id);
    } catch (e) {
      return Left(Failure(500, 'فشل إدراج الملف المرفق: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteUser(int userId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('users', where: 'id = ?', whereArgs: [userId]);
      return const Right(null);
    } catch (e) {
      return Left(Failure(500, 'فشل حذف حساب المستخدم: $e'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getClinicInfo() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db.query('clinics', where: 'id = 1');
      if (res.isNotEmpty) return Right(res.first);
      return const Right({'name': 'عيادتي الذكية', 'phone': '01000000000', 'address': 'الفرع الرئيسي'});
    } catch (e) {
      return Left(Failure(500, 'فشل جلب بيانات العيادة: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateClinicInfo(Map<String, dynamic> clinicInfo) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update('clinics', clinicInfo, where: 'id = 1');
      return const Right(null);
    } catch (e) {
      return Left(Failure(500, 'فشل تحديث بيانات العيادة: $e'));
    }
  }
}
