import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/common/widgets/app_dialog.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/enums/appointment_enums.dart';
import '../../../../core/enums/user_role.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/security/session_manager.dart';
import '../../../../core/security/shift_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../shared/cubit/block_builder_widget.dart';
import '../../../shift/view/shift_screen.dart';
import '../../data/cubit/clinic_cubit.dart';
import '../clinic_view_model.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  late final ClinicViewModel _viewModel;
  DateTime _selectedDate = DateTime.now();
  String _selectedStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _viewModel = sl<ClinicViewModel>()..updateRefresh(() {
      if (mounted) setState(() {});
    });
    _viewModel.clinicCubit.fetchAppointments(date: DateFormat('yyyy-MM-dd').format(_selectedDate));
    _viewModel.clinicCubit.fetchPatients();
    _viewModel.clinicCubit.fetchUsers();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _onAddAppointmentClick() {
    final hasShift = ShiftGuard.checkShiftOrWarn(
      context,
      onNavigateToShift: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShiftScreen()));
      },
    );

    if (hasShift) {
      _showBookingDialog(context);
    }
  }

  void _onDateSelected(DateTime date) {
    setState(() => _selectedDate = date);
    _viewModel.clinicCubit.fetchAppointments(date: DateFormat('yyyy-MM-dd').format(date));
  }

  List<Map<String, dynamic>> _getFilteredAppointments() {
    var list = _viewModel.clinicCubit.appointments;

    // Role-based filtering: Doctor sees only their appointments, Secretary/Admin sees all
    final currentUser = SessionManager.instance.currentUser;
    if (currentUser != null) {
      final userRole = UserRole.fromString(currentUser['role'] as String?);
      if (userRole == UserRole.doctor) {
        final currentUserId = currentUser['id'];
        final currentUserName = currentUser['full_name'];
        list = list.where((a) {
          final doctorId = a['user_id'];
          final doctorName = a['doctor_name'];
          return (doctorId != null && doctorId == currentUserId) ||
                 (doctorName != null && doctorName == currentUserName);
        }).toList();
      }
    }

    if (_selectedStatusFilter == 'all') return list;

    return list.where((a) {
      final status = AppointmentStatus.fromString(a['status'] as String?);
      return status.dbValue == _selectedStatusFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlockBuilderWidget<ClinicCubit, ClinicApiType>(
        types: const [ClinicApiType.getAppointments, ClinicApiType.addAppointment, ClinicApiType.updateAppointmentStatus],
        loading: (_) => const Center(child: CircularProgressIndicator()),
        body: (_) => ResponsiveLayout(
          mobile: _buildMobileLayout(),
          tablet: _buildTabletLayout(),
          desktop: _buildDesktopLayout(),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. Desktop Layout (>= 1024px) — Split View Workspace
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopLayout() {
    final appointments = _getFilteredAppointments();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('جدول المواعيد والحجوزات', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('إدارة حجز المواعيد، تنظيم جدول زيارات العيادة ومتابعة حالات الانتظار', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _onAddAppointmentClick,
                icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                label: const Text('تسجيل موعد جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // KPI Summary Row
          _buildKpiSummaryRow(),
          const SizedBox(height: 16),

          // Date Selector Bar & Status Filters
          _buildDateAndFilterBar(isMobile: false),
          const SizedBox(height: 16),

          // Main Split Workspace
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Panel (65%): Appointments Master Table
                Expanded(
                  flex: 6,
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'جدول مواعيد يوم ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                'إجمالي المواعيد: ${appointments.length}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Expanded(child: _buildAppointmentsListView(appointments, isMobile: false)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Right Panel (35%): Doctor Schedule Summary & Quick Stats
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
                                  SizedBox(width: 8),
                                  Text('تقويم المواعيد المباشر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              CalendarDatePicker(
                                initialDate: _selectedDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                onDateChanged: _onDateSelected,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. Tablet Layout (600px - 1023px) — Dual Column Grid
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTabletLayout() {
    final appointments = _getFilteredAppointments();

    return Padding(
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('جدول المواعيد والحجوزات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('إدارة حجز المواعيد وتنظيم زيارات العيادة', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _onAddAppointmentClick,
                icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 18),
                label: const Text('موعد جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildKpiSummaryRow(isMobile: true),
          const SizedBox(height: 14),
          _buildDateAndFilterBar(isMobile: false),
          const SizedBox(height: 14),
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: _buildAppointmentsListView(appointments, isMobile: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. Mobile Layout (< 600px) — Stack View
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout() {
    final appointments = _getFilteredAppointments();

    return Padding(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('جدول المواعيد والحجوزات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('تنظيم حجز وتوقيتات زيارات المرضى بالعيادة', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _onAddAppointmentClick,
              icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
              label: const Text('تسجيل موعد جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 14),
          _buildKpiSummaryRow(isMobile: true),
          const SizedBox(height: 14),
          _buildDateAndFilterBar(isMobile: true),
          const SizedBox(height: 14),
          Expanded(
            child: _buildAppointmentsListView(appointments, isMobile: true),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Shared Sub-Widgets
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildKpiSummaryRow({bool isMobile = false}) {
    final list = _viewModel.clinicCubit.appointments;

    final int total = list.length;
    final int waiting = list.where((a) => AppointmentStatus.fromString(a['status']).isWaiting).length;
    final int inProgress = list.where((a) => AppointmentStatus.fromString(a['status']).isInProgress).length;
    final int completed = list.where((a) => AppointmentStatus.fromString(a['status']).isCompleted).length;

    final items = [
      _KpiItem('إجمالي المواعيد', total.toString(), Icons.calendar_today, AppColors.secondary),
      _KpiItem('في الانتظار', waiting.toString(), Icons.hourglass_empty, Colors.amber),
      _KpiItem('جاري الكشف', inProgress.toString(), Icons.medical_services_outlined, AppColors.primary),
      _KpiItem('المكتملة', completed.toString(), Icons.check_circle_outline, AppColors.success),
    ];

    if (isMobile) {
      return Row(
        children: items.map((kpi) {
          return Expanded(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Column(
                  children: [
                    Icon(kpi.icon, color: kpi.color, size: 16),
                    const SizedBox(height: 2),
                    Text(kpi.value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kpi.color)),
                    Text(kpi.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    return Row(
      children: items.map((kpi) {
        return Expanded(
          child: Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: kpi.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(kpi.icon, color: kpi.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(kpi.value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kpi.color)),
                      Text(kpi.title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateAndFilterBar({required bool isMobile}) {
    final String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

    return Column(
      children: [
        Row(
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                elevation: 0,
              ),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) _onDateSelected(picked);
              },
              icon: const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 18),
              label: Text('التاريخ: $formattedDate', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _onDateSelected(DateTime.now()),
              child: const Text('اليوم', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('الكل', 'all'),
              _buildFilterChip('في الانتظار', 'waiting'),
              _buildFilterChip('جاري الكشف', 'in_progress'),
              _buildFilterChip('مكتمل', 'completed'),
              _buildFilterChip('ملغى', 'cancelled'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final bool isSelected = _selectedStatusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(left: 6.0),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
        selected: isSelected,
        selectedColor: AppColors.primary,
        onSelected: (val) {
          if (val) setState(() => _selectedStatusFilter = value);
        },
      ),
    );
  }

  Widget _buildAppointmentsListView(List<Map<String, dynamic>> list, {required bool isMobile}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_month_outlined, size: 48, color: AppColors.textLight),
            const SizedBox(height: 12),
            const Text('لا توجد مواعيد مسجلة تطابق التصفية الحالية', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: _onAddAppointmentClick,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('حجز موعد جديد', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final appt = list[index];
        final int apptId = appt['id'] as int;

        final statusEnum = AppointmentStatus.fromString(appt['status'] as String?);
        final typeEnum = AppointmentType.fromString(appt['type'] as String?);
        final priorityEnum = AppointmentPriority.fromString(appt['priority'] as String?);

        Color priorityColor = AppColors.textSecondary;
        if (priorityEnum == AppointmentPriority.urgent) priorityColor = Colors.orange;
        if (priorityEnum == AppointmentPriority.emergency) priorityColor = AppColors.error;

        Color statusColor = Colors.amber;
        if (statusEnum.isInProgress) statusColor = AppColors.primary;
        if (statusEnum.isCompleted) statusColor = AppColors.success;
        if (statusEnum.isCancelled) statusColor = Colors.grey;

        return Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: priorityEnum.isEmergency ? AppColors.error.withValues(alpha: 0.15) : AppColors.primaryLight,
              child: Text(
                '#${index + 1}',
                style: TextStyle(color: priorityEnum.isEmergency ? AppColors.error : AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    appt['patient_name'] ?? 'مريض غير معروف',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    priorityEnum.displayName,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: priorityColor),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              'التوقيت: ${appt['time_slot']} | النوع: ${typeEnum.displayName} | الطبيب: ${appt['doctor_name'] ?? 'غير محدد'}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: PopupMenuButton<String>(
              tooltip: 'خيارات الموعد',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(statusEnum.displayName, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, color: statusColor, size: 18),
                  ],
                ),
              ),
              onSelected: (newStatusKey) async {
                if (!ShiftGuard.checkShiftOrWarn(context)) return;
                await _viewModel.clinicCubit.updateAppointmentStatus(apptId, newStatusKey);
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'waiting', child: Text('في الانتظار ⏳')),
                const PopupMenuItem(value: 'in_progress', child: Text('جاري الكشف 🩺')),
                const PopupMenuItem(value: 'completed', child: Text('مكتمل ✅')),
                const PopupMenuItem(value: 'cancelled', child: Text('إلغاء الموعد ❌')),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBookingDialog(BuildContext context) {
    final patients = _viewModel.clinicCubit.patients;
    final users = _viewModel.clinicCubit.usersList;

    int? selectedPatientId = patients.isNotEmpty ? patients.first['id'] as int : null;
    AppointmentType selectedType = AppointmentType.newConsultation;
    AppointmentPriority selectedPriority = AppointmentPriority.normal;

    final String defaultDoctorName = users.isNotEmpty ? (users.first['full_name'] ?? 'د. محمد حسن') : 'د. محمد حسن';
    String selectedDoctor = defaultDoctorName;

    final notesController = TextEditingController();
    DateTime bookingDate = _selectedDate;
    TimeOfDay bookingTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final formattedDate = DateFormat('yyyy-MM-dd').format(bookingDate);
          final formattedTime = bookingTime.format(context);

          return AppDialog(
            title: 'تسجيل موعد حجز جديد',
            subtitle: 'أدخل بيانات الحجز والمريض لتسجيل الموعد بالعيادة',
            icon: Icons.calendar_month_rounded,
            iconColor: AppColors.primary,
            maxWidth: 560,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (patients.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ملاحظة: سيتم إنشاء سجل مريض جديد تلقائياً عند تأكيد الحجز.',
                            style: TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Appointment Type Selector
                DropdownButtonFormField<AppointmentType>(
                  initialValue: selectedType,
                  decoration: InputDecoration(
                    labelText: 'نوع الموعد (كشف/استشارة/متابعة) *',
                    prefixIcon: const Icon(Icons.medical_services_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: AppointmentType.values.map((t) {
                    return DropdownMenuItem(value: t, child: Text(t.displayName));
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedType = val!),
                ),
                const SizedBox(height: 14),

                // Patient Selector Dropdown
                if (patients.isNotEmpty) ...[
                  DropdownButtonFormField<int>(
                    initialValue: selectedPatientId,
                    decoration: InputDecoration(
                      labelText: 'اختر المريض *',
                      prefixIcon: const Icon(Icons.person_pin_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: patients.map((p) {
                      return DropdownMenuItem<int>(
                        value: p['id'] as int,
                        child: Text('#${p['id']} - ${p['name']} (${p['phone'] ?? ''})'),
                      );
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedPatientId = val),
                  ),
                  const SizedBox(height: 14),
                ],

                // Date & Time Row Pickers
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: bookingDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 1)),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (picked != null) {
                            setDialogState(() => bookingDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'تاريخ الحجز *',
                            prefixIcon: const Icon(Icons.calendar_month),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: bookingTime,
                          );
                          if (picked != null) {
                            setDialogState(() => bookingTime = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'وقت الحجز *',
                            prefixIcon: const Icon(Icons.access_time),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(formattedTime, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Assigned Doctor Selector
                DropdownButtonFormField<String>(
                  initialValue: selectedDoctor,
                  decoration: InputDecoration(
                    labelText: 'الطبيب المعالج *',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: users.isEmpty
                      ? const [DropdownMenuItem(value: 'د. محمد حسن', child: Text('د. محمد حسن'))]
                      : users.map((u) {
                          final name = u['full_name'] ?? 'د. محمد حسن';
                          return DropdownMenuItem<String>(
                            value: name,
                            child: Text(name.startsWith('د.') ? name : 'د. $name'),
                          );
                        }).toList(),
                  onChanged: (val) => setDialogState(() => selectedDoctor = val!),
                ),
                const SizedBox(height: 14),

                // Notes Field
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'سبب الزيارة / الشكوى الرئيسية (اختياري)',
                    prefixIcon: const Icon(Icons.notes),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),

                // Priority Selector Chips
                const Text('أولوية الحجز:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: AppointmentPriority.values.map((p) {
                    final isSelected = selectedPriority == p;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        child: ChoiceChip(
                          selected: isSelected,
                          selectedColor: p.isEmergency ? AppColors.error : AppColors.primary,
                          label: Text(
                            p.displayName,
                            style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                          onSelected: (_) => setDialogState(() => selectedPriority = p),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final user = SessionManager.instance.currentUser;
                  final shift = SessionManager.instance.activeShift;

                  int pId = selectedPatientId ?? 1;

                  if (patients.isEmpty) {
                    final newP = await _viewModel.clinicCubit.addPatient({
                      'name': 'مريض موعد جديد',
                      'phone': '01000000000',
                      'created_at': formattedDate,
                    });
                    newP.fold((_) {}, (id) => pId = id);
                  }

                  await _viewModel.clinicCubit.addAppointment({
                    'patient_id': pId,
                    'user_id': user != null ? user['id'] : 1,
                    'shift_id': shift != null ? shift['id'] : 1,
                    'appointment_date': formattedDate,
                    'time_slot': formattedTime,
                    'type': selectedType.dbValue,
                    'status': AppointmentStatus.waiting.dbValue,
                    'fee': 0.0,
                    'doctor_name': selectedDoctor,
                    'notes': notesController.text.trim(),
                    'priority': selectedPriority.dbValue,
                  });

                  if (dialogCtx.mounted) {
                    Navigator.of(dialogCtx).pop();
                  }
                  _viewModel.clinicCubit.fetchAppointments(date: formattedDate);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تسجيل وتأكيد الموعد بنجاح!'), backgroundColor: AppColors.success),
                    );
                  }
                },
                child: const Text('تأكيد الحجز', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KpiItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiItem(this.title, this.value, this.icon, this.color);
}
