import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/common/widgets/app_dialog.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/enums/appointment_enums.dart';
import '../../../../core/enums/user_role.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/security/session_manager.dart';
import '../../../../core/security/shift_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
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
        types: const [ClinicApiType.getAppointments, ClinicApiType.addAppointment, ClinicApiType.getWaitingRoom],
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
                                'جدول مواعيد يوم ${DateFormatter.formatDate(_selectedDate.toIso8601String())}',
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
              _buildFilterChip('جاري الكشف', AppointmentStatus.inProgress.dbValue),
              _buildFilterChip('في الانتظار', AppointmentStatus.waiting.dbValue),
              _buildFilterChip('مكتمل', AppointmentStatus.completed.dbValue),
              _buildFilterChip('ملغى', AppointmentStatus.cancelled.dbValue),
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(statusEnum.displayName, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  tooltip: 'إجراءات وخيارات الموعد',
                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                  onSelected: (action) {
                    if (!ShiftGuard.checkShiftOrWarn(context)) return;
                    switch (action) {
                      case 'confirm':
                        _confirmAppointment(appt);
                        break;
                      case 'check_in':
                        _checkInAppointment(appt);
                        break;
                      case 'reschedule':
                        _showRescheduleDialog(appt);
                        break;
                      case 'edit':
                        _showEditAppointmentDialog(appt);
                        break;
                      case 'whatsapp':
                        _sendWhatsAppReminder(appt);
                        break;
                      case 'print':
                        _printAppointmentTicket(appt);
                        break;
                      case 'cancel':
                        _cancelAppointment(appt);
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'confirm',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
                          SizedBox(width: 8),
                          Text('تأكيد الموعد (Confirm)'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'check_in',
                      child: Row(
                        children: [
                          Icon(Icons.medical_services_outlined, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text('إدخال للطابور (Check In)'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'reschedule',
                      child: Row(
                        children: [
                          Icon(Icons.edit_calendar_rounded, color: Colors.orange, size: 18),
                          SizedBox(width: 8),
                          Text('إعادة جدولة (Reschedule)'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_note_rounded, color: Colors.blue, size: 18),
                          SizedBox(width: 8),
                          Text('تعديل البيانات (Edit)'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'whatsapp',
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, color: Colors.green, size: 18),
                          SizedBox(width: 8),
                          Text('تذكير بالواتساب (WhatsApp)'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'print',
                      child: Row(
                        children: [
                          Icon(Icons.print_outlined, color: Colors.purple, size: 18),
                          SizedBox(width: 8),
                          Text('طباعة التذكرة (Print)'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Row(
                        children: [
                          Icon(Icons.cancel_outlined, color: AppColors.error, size: 18),
                          SizedBox(width: 8),
                          Text('إلغاء الموعد (Cancel)'),
                        ],
                      ),
                    ),
                  ],
                ),
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

    final List<String> doctorNames = users.isNotEmpty
        ? users.map((u) => (u['full_name'] as String? ?? 'د. محمد حسن')).toSet().toList()
        : ['د. محمد حسن'];

    int? selectedPatientId = patients.isNotEmpty ? patients.first['id'] as int : null;
    AppointmentType selectedType = AppointmentType.newConsultation;
    AppointmentPriority selectedPriority = AppointmentPriority.normal;

    final String defaultDoctorName = doctorNames.first;
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
                  items: doctorNames.map((name) {
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
                  if (!ShiftGuard.checkShiftOrWarn(context)) return;

                  final user = SessionManager.instance.currentUser;
                  final shift = SessionManager.instance.activeShift;

                  int pId = selectedPatientId ?? (patients.isNotEmpty ? (patients.first['id'] as int) : 1);

                  if (patients.isEmpty) {
                    final newP = await _viewModel.clinicCubit.addPatient({
                      'name': 'مريض موعد جديد',
                      'phone': '01000000000',
                      'created_at': formattedDate,
                    });
                    newP.fold((_) {}, (id) => pId = id);
                  }

                  final res = await _viewModel.clinicCubit.addAppointment({
                    'patient_id': pId,
                    'user_id': user != null ? user['id'] : 1,
                    'shift_id': shift != null ? shift['id'] : 1,
                    'clinic_id': user != null ? user['clinic_id'] : 1,
                    'appointment_date': formattedDate,
                    'time_slot': formattedTime,
                    'type': selectedType.dbValue,
                    'status': AppointmentStatus.waiting.dbValue,
                    'fee': 0.0,
                    'doctor_name': selectedDoctor,
                    'notes': notesController.text.trim(),
                    'priority': selectedPriority.dbValue,
                  });

                  res.fold(
                    (failure) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('فشل حجز الموعد: ${failure.message}'), backgroundColor: AppColors.error),
                        );
                      }
                    },
                    (id) {
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
                  );
                },
                child: const Text('تأكيد الحجز', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Action Handlers (All 7 Supported Actions)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _confirmAppointment(Map<String, dynamic> appt) async {
    await _viewModel.clinicCubit.updateAppointmentStatus(appt['id'] as int, 'waiting');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تأكيد الموعد ونقله إلى قائمة الانتظار بنجاح!'), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _checkInAppointment(Map<String, dynamic> appt) async {
    await _viewModel.clinicCubit.updateAppointmentStatus(appt['id'] as int, 'in_progress');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل حضور المريض وإدخاله لغرفة الكشف 🩺'), backgroundColor: AppColors.primary),
      );
    }
  }

  void _showRescheduleDialog(Map<String, dynamic> appt) {
    DateTime selectedDate = DateTime.tryParse(appt['appointment_date'] ?? '') ?? DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
          final formattedTime = selectedTime.format(context);

          return AppDialog(
            title: 'إعادة جدولة الموعد #${appt['id']}',
            subtitle: 'اختر تاريخ ووقت جديد لحجز المريض: ${appt['patient_name']}',
            icon: Icons.edit_calendar_rounded,
            iconColor: AppColors.primary,
            content: Column(
              children: [
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'التاريخ الجديد *', prefixIcon: Icon(Icons.calendar_month)),
                    child: Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: selectedTime);
                    if (picked != null) setDialogState(() => selectedTime = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'الوقت الجديد *', prefixIcon: Icon(Icons.access_time)),
                    child: Text(formattedTime, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () async {
                  await _viewModel.clinicCubit.rescheduleAppointment(appt['id'] as int, formattedDate, formattedTime);
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تمت إعادة جدولة الموعد بنجاح إلى $formattedDate $formattedTime'), backgroundColor: AppColors.success),
                    );
                  }
                },
                child: const Text('حفظ التعديل', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditAppointmentDialog(Map<String, dynamic> appt) {
    final users = _viewModel.clinicCubit.usersList;
    AppointmentType selectedType = AppointmentType.fromString(appt['type']);
    AppointmentPriority selectedPriority = AppointmentPriority.fromString(appt['priority']);
    String selectedDoctor = appt['doctor_name'] ?? (users.isNotEmpty ? users.first['full_name'] : 'د. محمد حسن');
    final notesController = TextEditingController(text: appt['notes'] ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AppDialog(
            title: 'تعديل بيانات الموعد #${appt['id']}',
            subtitle: 'تعديل بيانات الحجز للمريض: ${appt['patient_name']}',
            icon: Icons.edit_note_rounded,
            iconColor: AppColors.primary,
            content: Column(
              children: [
                DropdownButtonFormField<AppointmentType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'نوع الموعد', prefixIcon: Icon(Icons.medical_services)),
                  items: AppointmentType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.displayName))).toList(),
                  onChanged: (val) => setDialogState(() => selectedType = val!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedDoctor,
                  decoration: const InputDecoration(labelText: 'الطبيب المعالج', prefixIcon: Icon(Icons.badge)),
                  items: users.isEmpty
                      ? const [DropdownMenuItem(value: 'د. محمد حسن', child: Text('د. محمد حسن'))]
                      : users.map((u) => DropdownMenuItem(value: u['full_name'] as String, child: Text(u['full_name'] as String))).toList(),
                  onChanged: (val) => setDialogState(() => selectedDoctor = val!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'ملاحظات', prefixIcon: Icon(Icons.notes)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: AppointmentPriority.values.map((p) {
                    final isSelected = selectedPriority == p;
                    return Expanded(
                      child: ChoiceChip(
                        selected: isSelected,
                        label: Text(p.displayName),
                        onSelected: (_) => setDialogState(() => selectedPriority = p),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () async {
                  final updatedAppt = Map<String, dynamic>.from(appt);
                  updatedAppt['type'] = selectedType.dbValue;
                  updatedAppt['doctor_name'] = selectedDoctor;
                  updatedAppt['notes'] = notesController.text.trim();
                  updatedAppt['priority'] = selectedPriority.dbValue;

                  await _viewModel.clinicCubit.updateAppointment(updatedAppt);
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تحديث بيانات الموعد بنجاح!'), backgroundColor: AppColors.success),
                    );
                  }
                },
                child: const Text('حفظ التغييرات', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _sendWhatsAppReminder(Map<String, dynamic> appt) async {
    final phone = appt['patient_phone'] ?? '01000000000';
    final patientName = appt['patient_name'] ?? 'عزيزي المريض';
    final date = appt['appointment_date'] ?? '';
    final time = appt['time_slot'] ?? '';
    final doctor = appt['doctor_name'] ?? 'الطبيب';

    final text = 'أهلاً بك $patientName، نذكرك بموعدك بالعيادة يوم $date الساعة $time مع $doctor. نتمنى لك دوام الصحة والعافية.';
    final encodedText = Uri.encodeComponent(text);
    final cleanPhone = phone.toString().replaceAll(RegExp(r'\D'), '');
    final formattedPhone = cleanPhone.startsWith('0') ? '2$cleanPhone' : cleanPhone;
    final url = Uri.parse('https://wa.me/$formattedPhone?text=$encodedText');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم فتح الواتساب لإرسال تذكير الموعد إلى $phone!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر فتح تطبيق الواتساب: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _printAppointmentTicket(Map<String, dynamic> appt) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('تذكرة حجز موعد', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 8),
              pw.Text('رقم الموعد: #${appt['id']}'),
              pw.Text('اسم المريض: ${appt['patient_name'] ?? ''}'),
              pw.Text('تاريخ الحجز: ${appt['appointment_date'] ?? ''}'),
              pw.Text('وقت الحجز: ${appt['time_slot'] ?? ''}'),
              pw.Text('الطبيب المعالج: ${appt['doctor_name'] ?? ''}'),
              pw.Text('نوع الكشف: ${appt['type'] ?? ''}'),
              pw.SizedBox(height: 12),
              pw.Center(child: pw.Text('شكراً لزيارتكم العيادة')),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'appointment_ticket_${appt['id']}.pdf',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال تذكرة الموعد للطباعة بنجاح!'), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _cancelAppointment(Map<String, dynamic> appt) async {
    showDialog(
      context: context,
      builder: (dialogCtx) => AppDialog(
        title: 'تأكيد إلغاء الموعد',
        subtitle: 'هل أنت تأكد من إلغاء الموعد المحدد؟',
        icon: Icons.warning_amber_rounded,
        iconColor: AppColors.error,
        content: Text(
          'هل أنت تأكد من إلغاء موعد المريض: ${appt['patient_name']}؟',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('تراجع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await _viewModel.clinicCubit.updateAppointmentStatus(appt['id'] as int, 'cancelled');
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم إلغاء الموعد بنجاح'), backgroundColor: AppColors.error),
                );
              }
            },
            child: const Text('تأكيد الإلغاء', style: TextStyle(color: Colors.white)),
          ),
        ],
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
