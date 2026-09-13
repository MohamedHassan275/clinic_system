import 'package:dartz/dartz.dart';
import '../../../../core/common/error_handler/failure.dart';
import '../../../../core/security/session_manager.dart';
import '../../../shared/cubit/base_cubit.dart';
import '../repo/clinic_repo.dart';

enum ClinicApiType {
  none,
  getDashboard,
  getAppointments,
  addAppointment,
  updateAppointmentStatus,
  getWaitingRoom,
  getPatients,
  addPatient,
  getPatientRecord,
  addPrescription,
  getInvoices,
  createInvoice,
  getInventory,
  addInventoryItem,
  updateInventoryItem,
  getReports,
  getUsers,
  addUser,
  updateUser,
  updatePermissions,
  getClinicInfo,
  updateClinicInfo,
}

class ClinicCubit extends BaseCubit<ClinicApiType> {
  final ClinicRepo _clinicRepo;

  ClinicCubit(this._clinicRepo) : super(ClinicApiType.none);

  Map<String, dynamic> dashboardStats = {};
  List<Map<String, dynamic>> appointments = [];
  List<Map<String, dynamic>> waitingQueue = [];
  List<Map<String, dynamic>> patients = [];
  Map<String, dynamic>? selectedPatientRecord;
  List<Map<String, dynamic>> invoices = [];
  List<Map<String, dynamic>> inventoryItems = [];
  Map<String, dynamic> reportsData = {};
  List<Map<String, dynamic>> usersList = [];
  Map<String, dynamic>? clinicInfo;

  Future<Either<Failure, Map<String, dynamic>>> fetchDashboardStats() async {
    return await fastFire(
      type: ClinicApiType.getDashboard,
      fun: () => _clinicRepo.getDashboardStats(),
      onSuccess: (data) => dashboardStats = data,
    );
  }

  /// Convenience helper for total today's revenue
  double getTodayRevenue() => (dashboardStats['today_revenue'] as num?)?.toDouble() ?? 0.0;

  Future<Either<Failure, List<Map<String, dynamic>>>> fetchAppointments({String? date}) async {
    return await fastFire(
      type: ClinicApiType.getAppointments,
      fun: () => _clinicRepo.getAppointments(date: date),
      onSuccess: (list) => appointments = list,
    );
  }

  /// Alias for loading today's appointments
  Future<Either<Failure, List<Map<String, dynamic>>>> loadTodayAppointments({String? date}) => fetchAppointments(date: date);

  Future<Either<Failure, int>> addAppointment(Map<String, dynamic> appt) async {
    return await fastFire(
      type: ClinicApiType.addAppointment,
      fun: () => _clinicRepo.addAppointment(appt),
      onSuccess: (_) {
        fetchAppointments();
        fetchWaitingQueue();
        fetchDashboardStats();
      },
    );
  }

  /// Alias for booking an appointment
  Future<Either<Failure, int>> bookAppointment(Map<String, dynamic> appt) => addAppointment(appt);

  Future<Either<Failure, void>> updateAppointmentStatus(int id, String status) async {
    return await fastFire(
      type: ClinicApiType.updateAppointmentStatus,
      fun: () => _clinicRepo.updateAppointmentStatus(id, status),
      onSuccess: (_) {
        fetchAppointments();
        fetchWaitingQueue();
        fetchDashboardStats();
      },
    );
  }

  Future<Either<Failure, void>> updateAppointment(Map<String, dynamic> appt) async {
    return await fastFire(
      type: ClinicApiType.updateAppointmentStatus,
      fun: () => _clinicRepo.updateAppointment(appt),
      onSuccess: (_) {
        fetchAppointments();
        fetchWaitingQueue();
        fetchDashboardStats();
      },
    );
  }

  Future<Either<Failure, void>> rescheduleAppointment(int id, String newDate, String newTimeSlot) async {
    return await fastFire(
      type: ClinicApiType.updateAppointmentStatus,
      fun: () => _clinicRepo.rescheduleAppointment(id, newDate, newTimeSlot),
      onSuccess: (_) {
        fetchAppointments();
        fetchWaitingQueue();
        fetchDashboardStats();
      },
    );
  }

  /// Alias for checking in a patient to consultation room
  Future<Either<Failure, void>> checkInPatient(int appointmentId) => updateAppointmentStatus(appointmentId, 'جاري الكشف');

  Future<Either<Failure, List<Map<String, dynamic>>>> fetchWaitingQueue() async {
    return await fastFire(
      type: ClinicApiType.getWaitingRoom,
      fun: () => _clinicRepo.getWaitingRoomQueue(),
      onSuccess: (list) => waitingQueue = list,
    );
  }

  /// Alias for loading waiting list
  Future<Either<Failure, List<Map<String, dynamic>>>> getWaitingList() => fetchWaitingQueue();

  Future<Either<Failure, List<Map<String, dynamic>>>> fetchPatients({String? query}) async {
    return await fastFire(
      type: ClinicApiType.getPatients,
      fun: () => _clinicRepo.getPatients(query: query),
      onSuccess: (list) => patients = list,
    );
  }

  Future<Either<Failure, int>> addPatient(Map<String, dynamic> patient) async {
    return await fastFire(
      type: ClinicApiType.addPatient,
      fun: () => _clinicRepo.addPatient(patient),
      onSuccess: (_) {
        fetchPatients();
        fetchDashboardStats();
      },
    );
  }

  Future<Either<Failure, void>> updatePatient(Map<String, dynamic> patient) async {
    return await fastFire(
      type: ClinicApiType.getPatients,
      fun: () => _clinicRepo.updatePatient(patient),
      onSuccess: (_) {
        fetchPatients();
        final int id = patient['id'];
        fetchPatientRecord(id);
      },
    );
  }

  Future<Either<Failure, void>> deletePatient(int patientId) async {
    return await fastFire(
      type: ClinicApiType.getPatients,
      fun: () => _clinicRepo.deletePatient(patientId),
      onSuccess: (_) {
        selectedPatientRecord = null;
        fetchPatients();
        fetchDashboardStats();
      },
    );
  }

  Future<Either<Failure, Map<String, dynamic>>> fetchPatientRecord(int patientId) async {
    return await fastFire(
      type: ClinicApiType.getPatientRecord,
      fun: () => _clinicRepo.getPatientFullMedicalRecord(patientId),
      onSuccess: (record) => selectedPatientRecord = record,
    );
  }

  Future<Either<Failure, int>> addLabResult(Map<String, dynamic> result) async {
    final int pId = result['patient_id'];
    return await fastFire(
      type: ClinicApiType.getPatientRecord,
      fun: () => _clinicRepo.addLabResult(result),
      onSuccess: (_) => fetchPatientRecord(pId),
    );
  }

  Future<Either<Failure, int>> addPatientAttachment(Map<String, dynamic> attachment) async {
    final int pId = attachment['patient_id'];
    return await fastFire(
      type: ClinicApiType.getPatientRecord,
      fun: () => _clinicRepo.addPatientAttachment(attachment),
      onSuccess: (_) => fetchPatientRecord(pId),
    );
  }

  Future<Either<Failure, int>> addPrescription({
    required Map<String, dynamic> prescription,
    required List<Map<String, dynamic>> items,
  }) async {
    return await fastFire(
      type: ClinicApiType.addPrescription,
      fun: () => _clinicRepo.addPrescription(prescription: prescription, items: items),
      onSuccess: (_) {
        final pId = prescription['patient_id'];
        if (pId != null) fetchPatientRecord(pId as int);
        fetchDashboardStats();
      },
    );
  }

  Future<Either<Failure, List<Map<String, dynamic>>>> fetchInvoices() async {
    return await fastFire(
      type: ClinicApiType.getInvoices,
      fun: () => _clinicRepo.getInvoices(),
      onSuccess: (list) => invoices = list,
    );
  }

  Future<Either<Failure, int>> createInvoice(Map<String, dynamic> invoice) async {
    return await fastFire(
      type: ClinicApiType.createInvoice,
      fun: () => _clinicRepo.createInvoice(invoice),
      onSuccess: (_) {
        fetchInvoices();
        fetchDashboardStats();
      },
    );
  }

  Future<Either<Failure, List<Map<String, dynamic>>>> fetchInventory() async {
    return await fastFire(
      type: ClinicApiType.getInventory,
      fun: () => _clinicRepo.getInventory(),
      onSuccess: (list) => inventoryItems = list,
    );
  }

  Future<Either<Failure, int>> addInventoryItem(Map<String, dynamic> item) async {
    return await fastFire(
      type: ClinicApiType.addInventoryItem,
      fun: () => _clinicRepo.addInventoryItem(item),
      onSuccess: (_) {
        fetchInventory();
        fetchReports();
      },
    );
  }

  Future<Either<Failure, void>> updateInventoryItem(int id, int qty) async {
    return await fastFire(
      type: ClinicApiType.updateInventoryItem,
      fun: () => _clinicRepo.updateInventoryItem(id, qty),
      onSuccess: (_) {
        fetchInventory();
        fetchReports();
      },
    );
  }

  Future<Either<Failure, void>> deleteInventoryItem(int id) async {
    return await fastFire(
      type: ClinicApiType.updateInventoryItem,
      fun: () => _clinicRepo.deleteInventoryItem(id),
      onSuccess: (_) {
        fetchInventory();
        fetchReports();
      },
    );
  }

  Future<Either<Failure, Map<String, dynamic>>> fetchReports() async {
    return await fastFire(
      type: ClinicApiType.getReports,
      fun: () => _clinicRepo.getReports(),
      onSuccess: (data) => reportsData = data,
    );
  }

  Future<Either<Failure, List<Map<String, dynamic>>>> fetchUsers() async {
    return await fastFire(
      type: ClinicApiType.getUsers,
      fun: () => _clinicRepo.getUsers(),
      onSuccess: (list) {
        usersList = list;
        final current = SessionManager.instance.currentUser;
        if (current != null) {
          final matchingUser = list.firstWhere(
            (u) => u['id'] == current['id'] || u['username'] == current['username'],
            orElse: () => <String, dynamic>{},
          );
          if (matchingUser.isNotEmpty) {
            SessionManager.instance.setUserSession(matchingUser);
          }
        }
      },
    );
  }

  Future<Either<Failure, int>> addUser(Map<String, dynamic> user) async {
    return await fastFire(
      type: ClinicApiType.addUser,
      fun: () => _clinicRepo.addUser(user),
      onSuccess: (_) => fetchUsers(),
    );
  }

  Future<Either<Failure, void>> updateUser(Map<String, dynamic> user) async {
    return await fastFire(
      type: ClinicApiType.updateUser,
      fun: () => _clinicRepo.updateUser(user),
      onSuccess: (_) => fetchUsers(),
    );
  }

  Future<Either<Failure, void>> updateUserPermissions(int userId, List<String> perms) async {
    return await fastFire(
      type: ClinicApiType.updatePermissions,
      fun: () => _clinicRepo.updateUserPermissions(userId, perms),
      onSuccess: (_) => fetchUsers(),
    );
  }

  Future<Either<Failure, void>> deleteUser(int userId) async {
    return await fastFire(
      type: ClinicApiType.updateUser,
      fun: () => _clinicRepo.deleteUser(userId),
      onSuccess: (_) => fetchUsers(),
    );
  }

  Future<Either<Failure, Map<String, dynamic>>> fetchClinicInfo() async {
    return await fastFire(
      type: ClinicApiType.getClinicInfo,
      fun: () => _clinicRepo.getClinicInfo(),
      onSuccess: (info) => clinicInfo = info,
    );
  }

  Future<Either<Failure, void>> updateClinicInfo(Map<String, dynamic> info) async {
    return await fastFire(
      type: ClinicApiType.updateClinicInfo,
      fun: () => _clinicRepo.updateClinicInfo(info),
      onSuccess: (_) => fetchClinicInfo(),
    );
  }
}
