import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/common/error_handler/failure.dart';
import '../../../../core/database/database_helper.dart';
import 'clinic_repository.dart';

/// تنفيذ مستودع بيانات العيادة أوفلاين باستخدام SQLite (Local Clinic Repository)
class LocalClinicRepository implements ClinicRepository {
  String get _nowIso => DateTime.now().toUtc().toIso8601String();

  /// جلب remote_id للسجل المحلي (إن وجد) قبل إضافته لطابور المزامنة
  Future<String?> _getRemoteId(DatabaseExecutor executor, String tableName, int localId) async {
    final res = await executor.query(
      tableName,
      columns: ['remote_id'],
      where: 'id = ?',
      whereArgs: [localId],
    );
    if (res.isNotEmpty) {
      return res.first['remote_id'] as String?;
    }
    return null;
  }

  // ==========================================
  // 1. لوحة التحكم (Dashboard)
  // ==========================================

  @override
  Future<Either<Failure, Map<String, dynamic>>> getDashboardStats({int clinicId = 1}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      final apptRes = await db.rawQuery(
        'SELECT COUNT(*) as count FROM appointments WHERE clinic_id = ? AND date(appointment_date) = date(?) AND is_deleted = 0',
        [clinicId, todayStr],
      );
      final todayAppointments = Sqflite.firstIntValue(apptRes) ?? 0;

      final waitRes = await db.rawQuery(
        "SELECT COUNT(*) as count FROM appointments WHERE clinic_id = ? AND date(appointment_date) = date(?) AND status IN ('waiting', 'in_progress') AND is_deleted = 0",
        [clinicId, todayStr],
      );
      final waitingPatients = Sqflite.firstIntValue(waitRes) ?? 0;

      final completedRes = await db.rawQuery(
        "SELECT COUNT(*) as count FROM appointments WHERE clinic_id = ? AND date(appointment_date) = date(?) AND status = 'completed' AND is_deleted = 0",
        [clinicId, todayStr],
      );
      final completedAppointments = Sqflite.firstIntValue(completedRes) ?? 0;

      final revRes = await db.rawQuery(
        "SELECT COALESCE(SUM(paid_amount), 0.0) as total FROM invoices WHERE clinic_id = ? AND date(created_at) = date(?) AND is_deleted = 0 AND status != 'refunded'",
        [clinicId, todayStr],
      );
      final double todayRevenue = revRes.isNotEmpty ? (revRes.first['total'] as num? ?? 0.0).toDouble() : 0.0;

      return Right({
        'todayAppointments': todayAppointments,
        'waitingPatients': waitingPatients,
        'completedAppointments': completedAppointments,
        'todayRevenue': todayRevenue,
      });
    } catch (e) {
      return Left(Failure(400, "فشل جلب إحصائيات لوحة التحكم المحلية: $e"));
    }
  }

  // ==========================================
  // 2. المواعيد (Appointments)
  // ==========================================

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getAppointments({String? date}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      List<Map<String, dynamic>> results;

      if (date != null && date.isNotEmpty) {
        results = await db.rawQuery('''
          SELECT a.*, p.name as patient_name, p.phone as patient_phone, p.gender as patient_gender
          FROM appointments a
          LEFT JOIN patients p ON a.patient_id = p.id
          WHERE a.is_deleted = 0 AND date(a.appointment_date) = date(?)
          ORDER BY a.appointment_date ASC
        ''', [date]);
      } else {
        results = await db.rawQuery('''
          SELECT a.*, p.name as patient_name, p.phone as patient_phone, p.gender as patient_gender
          FROM appointments a
          LEFT JOIN patients p ON a.patient_id = p.id
          WHERE a.is_deleted = 0
          ORDER BY a.appointment_date DESC
        ''');
      }

      return Right(results);
    } catch (e) {
      return Left(Failure(400, "فشل جلب المواعيد المحلية: $e"));
    }
  }

  @override
  Future<Either<Failure, int>> addAppointment(Map<String, dynamic> appointment) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final data = Map<String, dynamic>.from(appointment);
      data['updated_at'] = _nowIso;
      data['sync_status'] = 'pending';
      data['is_deleted'] = 0;

      final id = await db.insert('appointments', data);
      data['id'] = id;

      await DatabaseHelper.instance.addToSyncQueue(
        tableName: 'appointments',
        recordId: id,
        remoteId: null,
        operation: 'INSERT',
        payload: data,
        executor: db,
      );

      return Right(id);
    } catch (e) {
      return Left(Failure(400, "فشل إضافة الموعد: $e"));
    }
  }

  @override
  Future<Either<Failure, void>> updateAppointmentStatus(int id, String status) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = _nowIso;
      final remoteId = await _getRemoteId(db, 'appointments', id);

      await db.update(
        'appointments',
        {
          'status': status,
          'updated_at': now,
          'sync_status': 'pending',
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      await DatabaseHelper.instance.addToSyncQueue(
        tableName: 'appointments',
        recordId: id,
        remoteId: remoteId,
        operation: 'UPDATE',
        payload: {
          'id': id,
          'remote_id': remoteId,
          'status': status,
          'updated_at': now,
        },
        executor: db,
      );

      return const Right(null);
    } catch (e) {
      return Left(Failure(400, "فشل تحديث حالة الموعد: $e"));
    }
  }

  @override
  Future<Either<Failure, void>> updateAppointment(Map<String, dynamic> appointment) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final id = appointment['id'] as int;
      final data = Map<String, dynamic>.from(appointment);
      final remoteId = await _getRemoteId(db, 'appointments', id);

      data['updated_at'] = _nowIso;
      data['sync_status'] = 'pending';
      if (remoteId != null) data['remote_id'] = remoteId;

      await db.update('appointments', data, where: 'id = ?', whereArgs: [id]);

      await DatabaseHelper.instance.addToSyncQueue(
        tableName: 'appointments',
        recordId: id,
        remoteId: remoteId,
        operation: 'UPDATE',
        payload: data,
        executor: db,
      );

      return const Right(null);
    } catch (e) {
      return Left(Failure(400, "فشل تحديث بيانات الموعد: $e"));
    }
  }

  @override
  Future<Either<Failure, void>> rescheduleAppointment(int id, String newDate, String newTimeSlot) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = _nowIso;
      final remoteId = await _getRemoteId(db, 'appointments', id);

      await db.update(
        'appointments',
        {
          'appointment_date': newDate,
          'time_slot': newTimeSlot,
          'updated_at': now,
          'sync_status': 'pending',
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      await DatabaseHelper.instance.addToSyncQueue(
        tableName: 'appointments',
        recordId: id,
        remoteId: remoteId,
        operation: 'UPDATE',
        payload: {
          'id': id,
          'remote_id': remoteId,
          'appointment_date': newDate,
          'time_slot': newTimeSlot,
          'updated_at': now,
        },
        executor: db,
      );

      return const Right(null);
    } catch (e) {
      return Left(Failure(400, "فشل إعادة جدولة الموعد: $e"));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAppointment(int appointmentId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = _nowIso;
      final remoteId = await _getRemoteId(db, 'appointments', appointmentId);

      await db.update(
        'appointments',
        {
          'is_deleted': 1,
          'updated_at': now,
          'sync_status': 'pending',
        },
        where: 'id = ?',
        whereArgs: [appointmentId],
      );

      await DatabaseHelper.instance.addToSyncQueue(
        tableName: 'appointments',
        recordId: appointmentId,
        remoteId: remoteId,
        operation: 'DELETE',
        payload: {
          'id': appointmentId,
          'remote_id': remoteId,
          'is_deleted': 1,
          'updated_at': now,
        },
        executor: db,
      );

      return const Right(null);
    } catch (e) {
      return Left(Failure(400, "فشل حذف الموعد: $e"));
    }
  }

  // ==========================================
  // 3. غرفة الانتظار (Waiting Room)
  // ==========================================

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getWaitingRoomQueue({int clinicId = 1, String? date}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final targetDate = date ?? DateTime.now().toIso8601String().substring(0, 10);

      final results = await db.rawQuery('''
        SELECT a.*, p.name as patient_name, p.phone as patient_phone, p.gender as patient_gender, p.age as patient_age
        FROM appointments a
        LEFT JOIN patients p ON a.patient_id = p.id
        WHERE a.clinic_id = ? AND date(a.appointment_date) = date(?) 
          AND a.status IN ('waiting', 'in_progress') AND a.is_deleted = 0
        ORDER BY CASE WHEN a.status = 'in_progress' THEN 0 ELSE 1 END, a.appointment_date ASC
      ''', [clinicId, targetDate]);

      return Right(results);
    } catch (e) {
      return Left(Failure(400, "فشل جلب قائمة الانتظار المحلية: $e"));
    }
  }

  // ==========================================
  // 4. المرضى والسجل الطبي (EMR & Patients)
  // ==========================================

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getPatients({String? query}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      List<Map<String, dynamic>> results;

      if (query != null && query.trim().isNotEmpty) {
        final q = '%${query.trim()}%';
        results = await db.rawQuery('''
          SELECT * FROM patients 
          WHERE is_deleted = 0 AND (name LIKE ? OR phone LIKE ? OR national_id LIKE ?)
          ORDER BY name ASC
        ''', [q, q, q]);
      } else {
        results = await db.rawQuery('SELECT * FROM patients WHERE is_deleted = 0 ORDER BY name ASC');
      }

      return Right(results);
    } catch (e) {
      return Left(Failure(400, "فشل جلب قائمة المرضى المحلية: $e"));
    }
  }

  @override
  Future<Either<Failure, int>> addPatient(Map<String, dynamic> patient) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final data = Map<String, dynamic>.from(patient);
      data['updated_at'] = _nowIso;
      data['sync_status'] = 'pending';
      data['is_deleted'] = 0;

      final id = await db.insert('patients', data);
      data['id'] = id;

      await DatabaseHelper.instance.addToSyncQueue(
        tableName: 'patients',
        recordId: id,
        remoteId: null,
        operation: 'INSERT',
        payload: data,
        executor: db,
      );

      return Right(id);
    } catch (e) {
      return Left(Failure(400, "فشل إضافة المريض: $e"));
    }
  }

  @override
  Future<Either<Failure, void>> updatePatient(Map<String, dynamic> patient) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final id = patient['id'] as int;
      final data = Map<String, dynamic>.from(patient);
      final remoteId = await _getRemoteId(db, 'patients', id);

      data['updated_at'] = _nowIso;
      data['sync_status'] = 'pending';
      if (remoteId != null) data['remote_id'] = remoteId;

      await db.update('patients', data, where: 'id = ?', whereArgs: [id]);

      await DatabaseHelper.instance.addToSyncQueue(
        tableName: 'patients',
        recordId: id,
        remoteId: remoteId,
        operation: 'UPDATE',
        payload: data,
        executor: db,
      );

      return const Right(null);
    } catch (e) {
      return Left(Failure(400, "فشل تحديث بيانات المريض: $e"));
    }
  }

  @override
  Future<Either<Failure, void>> deletePatient(int patientId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = _nowIso;
      final remoteId = await _getRemoteId(db, 'patients', patientId);

      await db.update(
        'patients',
        {
          'is_deleted': 1,
          'updated_at': now,
          'sync_status': 'pending',
        },
        where: 'id = ?',
        whereArgs: [patientId],
      );

      await DatabaseHelper.instance.addToSyncQueue(
        tableName: 'patients',
        recordId: patientId,
        remoteId: remoteId,
        operation: 'DELETE',
        payload: {
          'id': patientId,
          'remote_id': remoteId,
          'is_deleted': 1,
          'updated_at': now,
        },
        executor: db,
      );

      return const Right(null);
    } catch (e) {
      return Left(Failure(400, "فشل حذف المريض: $e"));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getPatientFullMedicalRecord(int patientId) async {
    try {
      final db = await DatabaseHelper.instance.database;

      final patientRes = await db.query('patients', where: 'id = ? AND is_deleted = 0', whereArgs: [patientId]);
      if (patientRes.isEmpty) {
        return Left(Failure(400, "المريض غير موجود أو تم حذفه"));
      }

      final appointments = await db.query('appointments', where: 'patient_id = ? AND is_deleted = 0', whereArgs: [patientId], orderBy: 'appointment_date DESC');
      final prescriptions = await db.query('prescriptions', where: 'patient_id = ? AND is_deleted = 0', whereArgs: [patientId], orderBy: 'created_at DESC');

      List<Map<String, dynamic>> fullPrescriptions = [];
      for (var p in prescriptions) {
        final pMap = Map<String, dynamic>.from(p);
        final pId = p['id'] as int;
        final items = await db.query('prescription_items', where: 'prescription_id = ? AND is_deleted = 0', whereArgs: [pId]);
        pMap['items'] = items;
        fullPrescriptions.add(pMap);
      }

      final labResults = await db.query('lab_results', where: 'patient_id = ? AND is_deleted = 0', whereArgs: [patientId], orderBy: 'created_at DESC');
      final attachments = await db.query('patient_attachments', where: 'patient_id = ? AND is_deleted = 0', whereArgs: [patientId], orderBy: 'created_at DESC');
      final invoices = await db.query('invoices', where: 'patient_id = ? AND is_deleted = 0', whereArgs: [patientId], orderBy: 'created_at DESC');

      return Right({
        'patient': patientRes.first,
        'appointments': appointments,
        'prescriptions': fullPrescriptions,
        'labResults': labResults,
        'attachments': attachments,
        'invoices': invoices,
      });
    } catch (e) {
      return Left(Failure(400, "فشل جلب السجل الطبي الكامل للمريض: $e"));
    }
  }

  // ==========================================
  // 5. الروشتات (Prescriptions)
  // ==========================================

  @override
  Future<Either<Failure, int>> addPrescription({
    required Map<String, dynamic> prescription,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      int prescriptionId = 0;
      final now = _nowIso;

      await db.transaction((txn) async {
        final pData = Map<String, dynamic>.from(prescription);
        pData['updated_at'] = now;
        pData['sync_status'] = 'pending';
        pData['is_deleted'] = 0;

        prescriptionId = await txn.insert('prescriptions', pData);
        pData['id'] = prescriptionId;

        await DatabaseHelper.instance.addToSyncQueue(
          tableName: 'prescriptions',
          recordId: prescriptionId,
          remoteId: null,
          operation: 'INSERT',
          payload: pData,
          executor: txn,
        );

        for (var item in items) {
          final itemData = Map<String, dynamic>.from(item);
          itemData['prescription_id'] = prescriptionId;
          itemData['updated_at'] = now;
          itemData['sync_status'] = 'pending';
          itemData['is_deleted'] = 0;

          final itemId = await txn.insert('prescription_items', itemData);
          itemData['id'] = itemId;

          await DatabaseHelper.instance.addToSyncQueue(
            tableName: 'prescription_items',
            recordId: itemId,
            remoteId: null,
            operation: 'INSERT',
            payload: itemData,
            executor: txn,
          );
        }
      });

      return Right(prescriptionId);
    } catch (e) {
      return Left(Failure(400, "فشل إنشاء وحفظ الروشتة: $e"));
    }
  }

  @override
  Future<Either<Failure, void>> deletePrescription(int prescriptionId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = _nowIso;

      await db.transaction((txn) async {
        final pRemoteId = await _getRemoteId(txn, 'prescriptions', prescriptionId);

        await txn.update(
          'prescriptions',
          {
            'is_deleted': 1,
            'updated_at': now,
            'sync_status': 'pending',
          },
          where: 'id = ?',
          whereArgs: [prescriptionId],
        );

        await DatabaseHelper.instance.addToSyncQueue(
          tableName: 'prescriptions',
          recordId: prescriptionId,
          remoteId: pRemoteId,
          operation: 'DELETE',
          payload: {
            'id': prescriptionId,
            'remote_id': pRemoteId,
            'is_deleted': 1,
            'updated_at': now,
          },
          executor: txn,
        );

        final itemRows = await txn.query(
          'prescription_items',
          columns: ['id', 'remote_id'],
          where: 'prescription_id = ?',
          whereArgs: [prescriptionId],
        );

        await txn.update(
          'prescription_items',
          {
            'is_deleted': 1,
            'updated_at': now,
            'sync_status': 'pending',
          },
          where: 'prescription_id = ?',
          whereArgs: [prescriptionId],
        );

        for (var row in itemRows) {
          final itemId = row['id'] as int;
          final itemRemoteId = row['remote_id'] as String?;
          await DatabaseHelper.instance.addToSyncQueue(
            tableName: 'prescription_items',
            recordId: itemId,
            remoteId: itemRemoteId,
            operation: 'DELETE',
            payload: {
              'id': itemId,
              'remote_id': itemRemoteId,
              'prescription_id': prescriptionId,
              'is_deleted': 1,
              'updated_at': now,
            },
            executor: txn,
          );
        }
      });

      return const Right(null);
    } catch (e) {
      return Left(Failure(400, "فشل حذف الروشتة وعناصرها: $e"));
    }
  }

  // ==========================================
  // 6. الفواتير والمحاسبة (Invoices & Billing)
  // ==========================================

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getInvoices() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.rawQuery('''
        SELECT i.*, p.name as patient_name, p.phone as patient_phone
        FROM invoices i
        LEFT JOIN patients p ON i.patient_id = p.id
        WHERE i.is_deleted = 0
        ORDER BY i.created_at DESC
      ''');

      return Right(results);
    } catch (e) {
      return Left(Failure(400, "فشل جلب قائمة الفواتير المحلية: $e"));
    }
  }

  @override
  Future<Either<Failure, int>> createInvoice(Map<String, dynamic> invoice) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final data = Map<String, dynamic>.from(invoice);
      data['updated_at'] = _nowIso;
      data['sync_status'] = 'pending';
      data['is_deleted'] = 0;

      final id = await db.insert('invoices', data);
      data['id'] = id;

      await DatabaseHelper.instance.addToSyncQueue(
        tableName: 'invoices',
        recordId: id,
        remoteId: null,
        operation: 'INSERT',
        payload: data,
        executor: db,
      );

      return Right(id);
    } catch (e) {
      return Left(Failure(400, "فشل إنشاء الفاتورة: $e"));
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
      final now = _nowIso;

      await db.transaction((txn) async {
        final invRemoteId = await _getRemoteId(txn, 'invoices', invoiceId);

        await txn.update(
          'invoices',
          {
            'status': 'refunded',
            'updated_at': now,
            'sync_status': 'pending',
          },
          where: 'id = ?',
          whereArgs: [invoiceId],
        );

        await DatabaseHelper.instance.addToSyncQueue(
          tableName: 'invoices',
          recordId: invoiceId,
          remoteId: invRemoteId,
          operation: 'UPDATE',
          payload: {
            'id': invoiceId,
            'remote_id': invRemoteId,
            'status': 'refunded',
            'updated_at': now,
          },
          executor: txn,
        );

        final refundPayload = {
          'invoice_id': invoiceId,
          'refund_amount': refundAmount,
          'amount': refundAmount,
          'reason': reason,
          'user_id': userId,
          'shift_id': shiftId,
          'patient_id': patientId,
          'clinic_id': 1,
          'created_at': now,
          'updated_at': now,
          'sync_status': 'pending',
        };

        final refundId = await txn.insert('refunds', refundPayload);

        await DatabaseHelper.instance.addToSyncQueue(
          tableName: 'refunds',
          recordId: refundId,
          remoteId: null,
          operation: 'INSERT',
          payload: refundPayload,
          executor: txn,
        );
      });

      return const Right(null);
    } catch (e) {
      return Left(Failure(400, "فشل استرجاع وتصفيات الفاتورة: $e"));
    }
  }

  @override
  Future<Either<Failure, void>> deleteInvoice(int invoiceId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = _nowIso;
      final remoteId = await _getRemoteId(db, 'invoices', invoiceId);

      await db.update(
        'invoices',
        {
          'is_deleted': 1,
          'updated_at': now,
          'sync_status': 'pending',
        },
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      await DatabaseHelper.instance.addToSyncQueue(
        tableName: 'invoices',
        recordId: invoiceId,
        remoteId: remoteId,
        operation: 'DELETE',
        payload: {
          'id': invoiceId,
          'remote_id': remoteId,
          'is_deleted': 1,
          'updated_at': now,
        },
        executor: db,
      );

      return const Right(null);
    } catch (e) {
      return Left(Failure(400, "فشل حذف الفاتورة: $e"));
    }
  }

  // ==========================================
  // 7. المخزن والمستلزمات (Inventory)
  // ==========================================

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getInventory() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.query('inventory', where: 'is_deleted = 0', orderBy: 'name ASC');
      return Right(results);
    } catch (e) {
      return Left(Failure(400, "فشل جلب عناصر المخزن المحلية: $e"));
    }
  }

  @override
  Future<Either<Failure, int>> addInventoryItem(Map<String, dynamic> item) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final data = Map<String, dynamic>.from(item);
      data['updated_at'] = _nowIso;
      data['sync_status'] = 'pending';
      data['is_deleted'] = 0;

      final id = await db.insert('inventory', data);
      data['id'] = id;

      await DatabaseHelper.instance.addToSyncQueue(
        tableName: 'inventory',
        recordId: id,
        remoteId: null,
        operation: 'INSERT',
        payload: data,
        executor: db,
      );

      return Right(id);
    } catch (e) {
      return Left(Failure(400, "فشل إضافة مستلزم المخزن: $e"));
    }
  }

  @override
  Future<Either<Failure, void>> updateInventoryItem(int id, int qty) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = _nowIso;
      final remoteId = await _getRemoteId(db, 'inventory', id);

      await db.update(
        'inventory',
        {
          'quantity': qty,
          'updated_at': now,
          'sync_status': 'pending',
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      await DatabaseHelper.instance.addToSyncQueue(
        tableName: 'inventory',
        recordId: id,
        remoteId: remoteId,
        operation: 'UPDATE',
        payload: {
          'id': id,
          'remote_id': remoteId,
          'quantity': qty,
          'updated_at': now,
        },
        executor: db,
      );

      return const Right(null);
    } catch (e) {
      return Left(Failure(400, "فشل تحديث كمية المخزن: $e"));
    }
  }

  @override
  Future<Either<Failure, void>> deleteInventoryItem(int id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = _nowIso;
      final remoteId = await _getRemoteId(db, 'inventory', id);

      await db.update(
        'inventory',
        {
          'is_deleted': 1,
          'updated_at': now,
          'sync_status': 'pending',
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      await DatabaseHelper.instance.addToSyncQueue(
        tableName: 'inventory',
        recordId: id,
        remoteId: remoteId,
        operation: 'DELETE',
        payload: {
          'id': id,
          'remote_id': remoteId,
          'is_deleted': 1,
          'updated_at': now,
        },
        executor: db,
      );

      return const Right(null);
    } catch (e) {
      return Left(Failure(400, "فشل حذف مستلزم المخزن: $e"));
    }
  }

  // ==========================================
  // 8. التقارير (Reports)
  // ==========================================

  @override
  Future<Either<Failure, Map<String, dynamic>>> getReports({
    int clinicId = 1,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;

      String dateWhere = 'clinic_id = ? AND is_deleted = 0';
      List<dynamic> args = [clinicId];

      if (startDate != null && endDate != null) {
        dateWhere += ' AND date(created_at) >= date(?) AND date(created_at) <= date(?)';
        args.addAll([startDate, endDate]);
      } else if (startDate != null) {
        dateWhere += ' AND date(created_at) >= date(?)';
        args.add(startDate);
      } else if (endDate != null) {
        dateWhere += ' AND date(created_at) <= date(?)';
        args.add(endDate);
      }

      final revRes = await db.rawQuery(
        "SELECT COALESCE(SUM(paid_amount), 0.0) as total_rev, COUNT(*) as inv_count FROM invoices WHERE $dateWhere AND status != 'refunded'",
        args,
      );
      final double totalRevenue = revRes.isNotEmpty ? (revRes.first['total_rev'] as num? ?? 0.0).toDouble() : 0.0;
      final int totalInvoices = revRes.isNotEmpty ? (revRes.first['inv_count'] as int? ?? 0) : 0;

      final patientCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM patients WHERE is_deleted = 0');
      final int totalPatients = Sqflite.firstIntValue(patientCountRes) ?? 0;

      final apptCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM appointments WHERE clinic_id = ? AND is_deleted = 0', [clinicId]);
      final int totalAppointments = Sqflite.firstIntValue(apptCountRes) ?? 0;

      return Right({
        'totalRevenue': totalRevenue,
        'totalInvoices': totalInvoices,
        'totalPatients': totalPatients,
        'totalAppointments': totalAppointments,
        'estimatedProfit': totalRevenue * 0.70,
      });
    } catch (e) {
      return Left(Failure(400, "فشل جلب التقرير المالي للعيادة: $e"));
    }
  }

  // ==========================================
  // 9. التحاليل والمرفقات (Lab & Attachments)
  // ==========================================

  @override
  Future<Either<Failure, int>> addLabResult(Map<String, dynamic> result) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final data = Map<String, dynamic>.from(result);
      data['updated_at'] = _nowIso;
      data['sync_status'] = 'pending';
      data['is_deleted'] = 0;

      final id = await db.insert('lab_results', data);
      data['id'] = id;

      await DatabaseHelper.instance.addToSyncQueue(
        tableName: 'lab_results',
        recordId: id,
        remoteId: null,
        operation: 'INSERT',
        payload: data,
        executor: db,
      );

      return Right(id);
    } catch (e) {
      return Left(Failure(400, "فشل إضافة نتيجة التحليل: $e"));
    }
  }

  @override
  Future<Either<Failure, int>> addPatientAttachment(Map<String, dynamic> attachment) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final data = Map<String, dynamic>.from(attachment);
      data['updated_at'] = _nowIso;
      data['sync_status'] = 'pending';
      data['is_deleted'] = 0;

      final id = await db.insert('patient_attachments', data);
      data['id'] = id;

      await DatabaseHelper.instance.addToSyncQueue(
        tableName: 'patient_attachments',
        recordId: id,
        remoteId: null,
        operation: 'INSERT',
        payload: data,
        executor: db,
      );

      return Right(id);
    } catch (e) {
      return Left(Failure(400, "فشل إضافة المرفق للمريض: $e"));
    }
  }

  // ==========================================
  // 10. المستخدمين وإعدادات العيادة (Staff & Settings)
  // ==========================================

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getUsers() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.query('users', where: 'is_deleted = 0', orderBy: 'name ASC');
      return Right(results);
    } catch (e) {
      return Left(Failure(400, "فشل جلب قائمة المستخدمين المحلية: $e"));
    }
  }

  @override
  Future<Either<Failure, int>> addUser(Map<String, dynamic> user) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final data = Map<String, dynamic>.from(user);
      data['updated_at'] = _nowIso;
      data['sync_status'] = 'pending';
      data['is_deleted'] = 0;

      final id = await db.insert('users', data);
      data['id'] = id;

      await DatabaseHelper.instance.addToSyncQueue(
        tableName: 'users',
        recordId: id,
        remoteId: null,
        operation: 'INSERT',
        payload: data,
        executor: db,
      );

      return Right(id);
    } catch (e) {
      return Left(Failure(400, "فشل إضافة المستخدم: $e"));
    }
  }

  @override
  Future<Either<Failure, void>> updateUser(Map<String, dynamic> user) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final id = user['id'] as int;
      final data = Map<String, dynamic>.from(user);
      final remoteId = await _getRemoteId(db, 'users', id);

      data['updated_at'] = _nowIso;
      data['sync_status'] = 'pending';
      if (remoteId != null) data['remote_id'] = remoteId;

      await db.update('users', data, where: 'id = ?', whereArgs: [id]);

      await DatabaseHelper.instance.addToSyncQueue(
        tableName: 'users',
        recordId: id,
        remoteId: remoteId,
        operation: 'UPDATE',
        payload: data,
        executor: db,
      );

      return const Right(null);
    } catch (e) {
      return Left(Failure(400, "فشل تحديث بيانات المستخدم: $e"));
    }
  }

  @override
  Future<Either<Failure, void>> updateUserPermissions(int userId, List<String> permissions) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = _nowIso;
      final permStr = jsonEncode(permissions);
      final remoteId = await _getRemoteId(db, 'users', userId);

      await db.update(
        'users',
        {
          'permissions': permStr,
          'updated_at': now,
          'sync_status': 'pending',
        },
        where: 'id = ?',
        whereArgs: [userId],
      );

      await DatabaseHelper.instance.addToSyncQueue(
        tableName: 'users',
        recordId: userId,
        remoteId: remoteId,
        operation: 'UPDATE',
        payload: {
          'id': userId,
          'remote_id': remoteId,
          'permissions': permStr,
          'updated_at': now,
        },
        executor: db,
      );

      return const Right(null);
    } catch (e) {
      return Left(Failure(400, "فشل تحديث صلاحيات المستخدم: $e"));
    }
  }

  @override
  Future<Either<Failure, void>> deleteUser(int userId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = _nowIso;
      final remoteId = await _getRemoteId(db, 'users', userId);

      await db.update(
        'users',
        {
          'is_deleted': 1,
          'updated_at': now,
          'sync_status': 'pending',
        },
        where: 'id = ?',
        whereArgs: [userId],
      );

      await DatabaseHelper.instance.addToSyncQueue(
        tableName: 'users',
        recordId: userId,
        remoteId: remoteId,
        operation: 'DELETE',
        payload: {
          'id': userId,
          'remote_id': remoteId,
          'is_deleted': 1,
          'updated_at': now,
        },
        executor: db,
      );

      return const Right(null);
    } catch (e) {
      return Left(Failure(400, "فشل حذف المستخدم: $e"));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getClinicInfo() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.query('clinics', limit: 1);
      if (results.isEmpty) {
        return Left(Failure(400, "بيانات العيادة غير موجودة"));
      }
      return Right(results.first);
    } catch (e) {
      return Left(Failure(400, "فشل جلب بيانات العيادة المحلية: $e"));
    }
  }

  @override
  Future<Either<Failure, void>> updateClinicInfo(Map<String, dynamic> clinicInfo) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final id = clinicInfo['id'] as int? ?? 1;
      final data = Map<String, dynamic>.from(clinicInfo);
      final remoteId = await _getRemoteId(db, 'clinics', id);

      data['updated_at'] = _nowIso;
      data['sync_status'] = 'pending';
      if (remoteId != null) data['remote_id'] = remoteId;

      await db.update('clinics', data, where: 'id = ?', whereArgs: [id]);

      await DatabaseHelper.instance.addToSyncQueue(
        tableName: 'clinics',
        recordId: id,
        remoteId: remoteId,
        operation: 'UPDATE',
        payload: data,
        executor: db,
      );

      return const Right(null);
    } catch (e) {
      return Left(Failure(400, "فشل تحديث بيانات العيادة: $e"));
    }
  }

  // ==========================================
  // 11. التصنيفات والخدمات والتأمين (Categories, Services & Insurance)
  // ==========================================

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getCategories({String? type}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      List<Map<String, dynamic>> results;
      if (type != null && type.isNotEmpty) {
        results = await db.query('categories', where: 'is_deleted = 0 AND type = ?', whereArgs: [type], orderBy: 'name ASC');
      } else {
        results = await db.query('categories', where: 'is_deleted = 0', orderBy: 'name ASC');
      }
      return Right(results);
    } catch (e) {
      return Left(Failure(400, "فشل جلب التصنيفات المحلية: $e"));
    }
  }

  @override
  Future<Either<Failure, int>> addCategory(Map<String, dynamic> category) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final data = Map<String, dynamic>.from(category);
      data['updated_at'] = _nowIso;
      data['sync_status'] = 'pending';
      data['is_deleted'] = 0;

      final id = await db.insert('categories', data);
      data['id'] = id;

      await DatabaseHelper.instance.addToSyncQueue(
        tableName: 'categories',
        recordId: id,
        remoteId: null,
        operation: 'INSERT',
        payload: data,
        executor: db,
      );

      return Right(id);
    } catch (e) {
      return Left(Failure(400, "فشل إضافة التصنيف: $e"));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getServices() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.query('services', where: 'is_deleted = 0', orderBy: 'name ASC');
      return Right(results);
    } catch (e) {
      return Left(Failure(400, "فشل جلب خدمات العيادة المحلية: $e"));
    }
  }

  @override
  Future<Either<Failure, int>> addService(Map<String, dynamic> service) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final data = Map<String, dynamic>.from(service);
      data['updated_at'] = _nowIso;
      data['sync_status'] = 'pending';
      data['is_deleted'] = 0;

      final id = await db.insert('services', data);
      data['id'] = id;

      await DatabaseHelper.instance.addToSyncQueue(
        tableName: 'services',
        recordId: id,
        remoteId: null,
        operation: 'INSERT',
        payload: data,
        executor: db,
      );

      return Right(id);
    } catch (e) {
      return Left(Failure(400, "فشل إضافة الخدمة: $e"));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getInsuranceCompanies() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.query('insurance_companies', where: 'is_deleted = 0', orderBy: 'name ASC');
      return Right(results);
    } catch (e) {
      return Left(Failure(400, "فشل جلب شركات التأمين المحلية: $e"));
    }
  }

  @override
  Future<Either<Failure, int>> addInsuranceCompany(Map<String, dynamic> company) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final data = Map<String, dynamic>.from(company);
      data['updated_at'] = _nowIso;
      data['sync_status'] = 'pending';
      data['is_deleted'] = 0;

      final id = await db.insert('insurance_companies', data);
      data['id'] = id;

      await DatabaseHelper.instance.addToSyncQueue(
        tableName: 'insurance_companies',
        recordId: id,
        remoteId: null,
        operation: 'INSERT',
        payload: data,
        executor: db,
      );

      return Right(id);
    } catch (e) {
      return Left(Failure(400, "فشل إضافة شركة التأمين: $e"));
    }
  }
}
