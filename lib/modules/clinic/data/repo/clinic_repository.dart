import 'package:dartz/dartz.dart';
import '../../../../core/common/error_handler/failure.dart';

/// واجهة مستودع بيانات العيادة (Interface)
/// تحتوي على تعريف كافة العمليات المتاحة في النظام بدون أي تفاصيل تنفيذية
abstract class ClinicRepository {
  // ==========================================
  // 1. لوحة التحكم (Dashboard)
  // ==========================================

  /// جلب إحصائيات لوحة التحكم للعيادة
  Future<Either<Failure, Map<String, dynamic>>> getDashboardStats({int clinicId = 1});

  // ==========================================
  // 2. المواعيد (Appointments)
  // ==========================================

  /// جلب قائمة المواعيد (مع إمكانية الفلترة بتاريخ محدد)
  Future<Either<Failure, List<Map<String, dynamic>>>> getAppointments({String? date});

  /// إضافة موعد جديد
  Future<Either<Failure, int>> addAppointment(Map<String, dynamic> appointment);

  /// تحديث حالة الموعد (مثال: waiting, in_progress, completed, cancelled)
  Future<Either<Failure, void>> updateAppointmentStatus(int id, String status);

  /// تحديث كافة بيانات الموعد
  Future<Either<Failure, void>> updateAppointment(Map<String, dynamic> appointment);

  /// إعادة جدولة الموعد بتاريخ ووقت جديدين
  Future<Either<Failure, void>> rescheduleAppointment(int id, String newDate, String newTimeSlot);

  /// حذف موعد (حذف منطقي is_deleted = 1)
  Future<Either<Failure, void>> deleteAppointment(int appointmentId);

  // ==========================================
  // 3. غرفة الانتظار (Waiting Room)
  // ==========================================

  /// جلب طابور قائمة الانتظار للمرضى لليوم أو تاريخ محدد مرتبة حسب الأولوية
  Future<Either<Failure, List<Map<String, dynamic>>>> getWaitingRoomQueue({int clinicId = 1, String? date});

  // ==========================================
  // 4. المرضى والسجل الطبي (EMR & Patients)
  // ==========================================

  /// جلب قائمة المرضى (مع إمكانية البحث بالاسم، الهاتف، الرقم القومي، إلخ)
  Future<Either<Failure, List<Map<String, dynamic>>>> getPatients({String? query});

  /// إضافة مريض جديد
  Future<Either<Failure, int>> addPatient(Map<String, dynamic> patient);

  /// تحديث بيانات مريض
  Future<Either<Failure, void>> updatePatient(Map<String, dynamic> patient);

  /// حذف سجل مريض (حذف منطقي)
  Future<Either<Failure, void>> deletePatient(int patientId);

  /// جلب الملف الطبي الكامل للمريض (بيانات المريض، المواعيد، الروشتات، التحاليل، المرفقات)
  Future<Either<Failure, Map<String, dynamic>>> getPatientFullMedicalRecord(int patientId);

  // ==========================================
  // 5. الروشتات (Prescriptions)
  // ==========================================

  /// إضافة روشتة جديدة مع الأدوية/العناصر التابعة لها
  Future<Either<Failure, int>> addPrescription({
    required Map<String, dynamic> prescription,
    required List<Map<String, dynamic>> items,
  });

  /// حذف روشتة (حذف منطقي)
  Future<Either<Failure, void>> deletePrescription(int prescriptionId);

  // ==========================================
  // 6. الفواتير والمحاسبة (Invoices & Billing)
  // ==========================================

  /// جلب كافة الفواتير
  Future<Either<Failure, List<Map<String, dynamic>>>> getInvoices();

  /// إنشاء فاتورة جديدة
  Future<Either<Failure, int>> createInvoice(Map<String, dynamic> invoice);

  /// استرجاع/استرداد فاتورة (مبلغ جزئي أو كلي)
  Future<Either<Failure, void>> refundInvoice({
    required int invoiceId,
    required double refundAmount,
    required String reason,
    required int userId,
    required int shiftId,
    required int patientId,
  });

  /// حذف فاتورة (حذف منطقي)
  Future<Either<Failure, void>> deleteInvoice(int invoiceId);

  // ==========================================
  // 7. المخزن والمستلزمات (Inventory)
  // ==========================================

  /// جلب قائمة عناصر/مستلزمات المخزن
  Future<Either<Failure, List<Map<String, dynamic>>>> getInventory();

  /// إضافة مستلزم جديد للمخزن
  Future<Either<Failure, int>> addInventoryItem(Map<String, dynamic> item);

  /// تحديث كمية مستلزم في المخزن
  Future<Either<Failure, void>> updateInventoryItem(int id, int qty);

  /// حذف مستلزم من المخزن (حذف منطقي)
  Future<Either<Failure, void>> deleteInventoryItem(int id);

  // ==========================================
  // 8. التقارير (Reports)
  // ==========================================

  /// جلب التقرير المالي والإحصائي للعيادة
  Future<Either<Failure, Map<String, dynamic>>> getReports({
    int clinicId = 1,
    String? startDate,
    String? endDate,
  });

  // ==========================================
  // 9. التحاليل والمرفقات (Lab & Attachments)
  // ==========================================

  /// إضافة نتيجة تحليل مريض
  Future<Either<Failure, int>> addLabResult(Map<String, dynamic> result);

  /// إضافة مرفق/ملف جديد لمريض
  Future<Either<Failure, int>> addPatientAttachment(Map<String, dynamic> attachment);

  // ==========================================
  // 10. المستخدمين وإعدادات العيادة (Staff & Settings)
  // ==========================================

  /// جلب قائمة المستخدمين/الموظفين
  Future<Either<Failure, List<Map<String, dynamic>>>> getUsers();

  /// إضافة مستخدم جديد
  Future<Either<Failure, int>> addUser(Map<String, dynamic> user);

  /// تحديث بيانات مستخدم
  Future<Either<Failure, void>> updateUser(Map<String, dynamic> user);

  /// تحديث صلاحيات المستخدم
  Future<Either<Failure, void>> updateUserPermissions(int userId, List<String> permissions);

  /// حذف حساب مستخدم (حذف منطقي)
  Future<Either<Failure, void>> deleteUser(int userId);

  /// جلب بيانات العيادة
  Future<Either<Failure, Map<String, dynamic>>> getClinicInfo();

  /// تحديث بيانات العيادة
  Future<Either<Failure, void>> updateClinicInfo(Map<String, dynamic> clinicInfo);

  // ==========================================
  // 11. التصنيفات والخدمات والتأمين (Categories, Services & Insurance)
  // ==========================================

  /// جلب التصنيفات (مع إمكانية الفلترة بالنوع)
  Future<Either<Failure, List<Map<String, dynamic>>>> getCategories({String? type});

  /// إضافة تصنيف جديد
  Future<Either<Failure, int>> addCategory(Map<String, dynamic> category);

  /// جلب خدمات العيادة المتاحة
  Future<Either<Failure, List<Map<String, dynamic>>>> getServices();

  /// إضافة خدمة جديدة للعيادة
  Future<Either<Failure, int>> addService(Map<String, dynamic> service);

  /// جلب قائمة شركات التأمين المتعاقد عليها
  Future<Either<Failure, List<Map<String, dynamic>>>> getInsuranceCompanies();

  /// إضافة شركة تأمين جديدة
  Future<Either<Failure, int>> addInsuranceCompany(Map<String, dynamic> company);
}
