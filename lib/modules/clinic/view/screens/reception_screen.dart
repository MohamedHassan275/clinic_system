import 'package:flutter/material.dart';
import '../../../../core/common/widgets/app_dialog.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/enums/appointment_enums.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/security/shift_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../shared/cubit/block_builder_widget.dart';
import '../../data/cubit/clinic_cubit.dart';
import '../../../main_shell/view/main_shell_view_model.dart';
import '../clinic_view_model.dart';

class ReceptionScreen extends StatefulWidget {
  const ReceptionScreen({super.key});

  @override
  State<ReceptionScreen> createState() => _ReceptionScreenState();
}

class _ReceptionScreenState extends State<ReceptionScreen> {
  late final ClinicViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = sl<ClinicViewModel>()..updateRefresh(() {
      if (mounted) setState(() {});
    });
    _viewModel.clinicCubit.fetchWaitingQueue();
    _viewModel.clinicCubit.fetchAppointments();
    _viewModel.clinicCubit.fetchPatients();
    _viewModel.clinicCubit.fetchServices();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlockBuilderWidget<ClinicCubit, ClinicApiType>(
        types: const [
          ClinicApiType.getWaitingRoom,
          ClinicApiType.getAppointments,
          ClinicApiType.getPatients,
        ],
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
  // 1. Desktop Layout (>= 1024px) — Split View with Master List & Quick Actions
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isMobile: false),
          const SizedBox(height: 20),
          _buildKpiSummaryRow(),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Right Side (65%): Waiting Room & Today Queue
                Expanded(
                  flex: 6,
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            title: 'قائمة انتظار المرضى لليوم',
                            subtitle: 'إدارة دخول وخروج المرضى للكشف وحالات الانتظار',
                            icon: Icons.people_alt_rounded,
                          ),
                          const SizedBox(height: 16),
                          Expanded(child: _buildQueueListView(isMobile: false)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // Left Side (35%): Quick Actions Panel & Recent Bookings
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      _buildQuickActionsCard(),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle(
                                  title: 'أحدث المواعيد المحجوزة',
                                  subtitle: 'جدول الحجوزات القادمة اليوم',
                                  icon: Icons.calendar_month_rounded,
                                ),
                                const SizedBox(height: 12),
                                Expanded(child: _buildAppointmentsListView(isCompact: true)),
                              ],
                            ),
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
  // 2. Tablet Layout (600px - 1023px) — Grid & Dual Cards
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTabletLayout() {
    return Padding(
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isMobile: false),
          const SizedBox(height: 16),
          _buildKpiSummaryRow(),
          const SizedBox(height: 16),
          _buildQuickActionButtonsBar(),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            title: 'قائمة الانتظار الحالية',
                            icon: Icons.people_alt_rounded,
                          ),
                          const SizedBox(height: 12),
                          Expanded(child: _buildQueueListView(isMobile: true)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            title: 'الحجوزات القادمة اليوم',
                            icon: Icons.calendar_month_rounded,
                          ),
                          const SizedBox(height: 12),
                          Expanded(child: _buildAppointmentsListView(isCompact: true)),
                        ],
                      ),
                    ),
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
  // 3. Mobile Layout (< 600px) — Stack View with Bottom Quick Actions
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isMobile: true),
          const SizedBox(height: 14),
          _buildKpiSummaryRow(isMobile: true),
          const SizedBox(height: 14),
          _buildQuickActionButtonsBar(isMobile: true),
          const SizedBox(height: 16),
          _buildSectionTitle(
            title: 'قائمة انتظار الاستقبال اليوم',
            subtitle: 'سجل دخول المرضى للكشف',
            icon: Icons.people_alt_rounded,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 380,
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: _buildQueueListView(isMobile: true),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionTitle(
            title: 'الحجوزات القادمة اليوم',
            icon: Icons.calendar_month_rounded,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 300,
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: _buildAppointmentsListView(isCompact: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Shared Sub-Widgets & Components
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader({required bool isMobile}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'منصة مكتب الاستقبال (Reception)',
              style: TextStyle(
                fontSize: isMobile ? 18 : 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'تسجيل المرضى، تنظيم الأدوار، وإدارة الحجوزات اليومية',
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle({required String title, String? subtitle, required IconData icon}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiSummaryRow({bool isMobile = false}) {
    final queue = _viewModel.clinicCubit.waitingQueue;
    final int waitingCount = queue.where((q) => AppointmentStatus.fromString(q['status']).isWaiting).length;
    final int inConsultationCount = queue.where((q) => AppointmentStatus.fromString(q['status']).isInProgress).length;
    final int completedCount = queue.where((q) => AppointmentStatus.fromString(q['status']).isCompleted).length;

    final items = [
      _KpiData('في الانتظار', waitingCount.toString(), Icons.hourglass_empty_rounded, Colors.amber),
      _KpiData('جاري الكشف', inConsultationCount.toString(), Icons.medical_services_outlined, AppColors.primary),
      _KpiData('كشوفات مكتملة', completedCount.toString(), Icons.check_circle_outline, AppColors.success),
    ];

    if (isMobile) {
      return Row(
        children: items.map((kpi) {
          return Expanded(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: Column(
                  children: [
                    Icon(kpi.icon, color: kpi.color, size: 20),
                    const SizedBox(height: 4),
                    Text(kpi.value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kpi.color)),
                    Text(kpi.title, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
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
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: kpi.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(kpi.icon, color: kpi.color, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(kpi.value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kpi.color)),
                      Text(kpi.title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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

  Widget _buildQuickActionsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              title: 'إجراءات الاستقبال السريعة',
              subtitle: 'اختصارات التعامل اليومية والتحصيل',
              icon: Icons.flash_on_rounded,
            ),
            const SizedBox(height: 14),
            _buildActionButton(
              label: '+ تسجيل مريض جديد',
              icon: Icons.person_add_alt_1_rounded,
              color: AppColors.primary,
              onPressed: () => _onRegisterNewPatient(),
            ),
            const SizedBox(height: 10),
            _buildActionButton(
              label: '+ حجز موعد جديد',
              icon: Icons.add_alarm_rounded,
              color: AppColors.secondary,
              onPressed: () => _onBookAppointment(),
            ),
            const SizedBox(height: 10),
            _buildActionButton(
              label: '💰 تحصيل فاتورة / الحسابات',
              icon: Icons.receipt_long_rounded,
              color: Colors.teal,
              onPressed: () => sl<MainShellViewModel>().selectTabByKey('billing'),
            ),
            const SizedBox(height: 10),
            _buildActionButton(
              label: '👤 البحث في ملفات المرضى',
              icon: Icons.folder_shared_rounded,
              color: Colors.blueGrey,
              onPressed: () => sl<MainShellViewModel>().selectTabByKey('emr'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButtonsBar({bool isMobile = false}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        SizedBox(
          width: isMobile ? 160 : 180,
          child: _buildActionButton(
            label: isMobile ? '+ مريض' : '+ تسجيل مريض',
            icon: Icons.person_add_alt_1_rounded,
            color: AppColors.primary,
            onPressed: () => _onRegisterNewPatient(),
          ),
        ),
        SizedBox(
          width: isMobile ? 160 : 180,
          child: _buildActionButton(
            label: isMobile ? '+ موعد' : '+ حجز موعد',
            icon: Icons.add_alarm_rounded,
            color: AppColors.secondary,
            onPressed: () => _onBookAppointment(),
          ),
        ),
        SizedBox(
          width: isMobile ? 160 : 180,
          child: _buildActionButton(
            label: isMobile ? '💰 تحصيل' : '💰 الحسابات',
            icon: Icons.receipt_long_rounded,
            color: Colors.teal,
            onPressed: () => sl<MainShellViewModel>().selectTabByKey('billing'),
          ),
        ),
        SizedBox(
          width: isMobile ? 160 : 180,
          child: _buildActionButton(
            label: isMobile ? '👤 ملفات' : '👤 ملفات المرضى',
            icon: Icons.folder_shared_rounded,
            color: Colors.blueGrey,
            onPressed: () => sl<MainShellViewModel>().selectTabByKey('emr'),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 18),
        label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _buildQueueListView({required bool isMobile}) {
    final queue = _viewModel.clinicCubit.waitingQueue;
    if (queue.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48, color: AppColors.textLight),
            SizedBox(height: 12),
            Text('لا يوجد مرضى في الانتظار حالياً', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: queue.length,
      separatorBuilder: (ctx, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = queue[index];
        final apptStatus = AppointmentStatus.fromString(item['status'] as String?);
        final apptType = AppointmentType.fromString(item['type'] as String?);

        Color statusColor = Colors.amber;
        if (apptStatus.isInProgress) statusColor = AppColors.primary;
        if (apptStatus.isCompleted) statusColor = AppColors.success;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: statusColor.withValues(alpha: 0.15),
            child: Text(
              '#${index + 1}',
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          title: Text(item['patient_name'] ?? 'مريض', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text('النوع: ${apptType.displayName} | الوقت: ${item['time_slot'] ?? 'غير محدد'}', style: const TextStyle(fontSize: 12)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(apptStatus.displayName, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              if (apptStatus.isWaiting) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.login, color: AppColors.primary, size: 20),
                  tooltip: 'إدخال للطبيب',
                  onPressed: () async {
                    if (!ShiftGuard.checkShiftOrWarn(context)) return;
                    final int apptId = item['id'] as int;
                    await _viewModel.clinicCubit.checkInPatient(apptId);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppointmentsListView({required bool isCompact}) {
    final appointments = _viewModel.clinicCubit.appointments;
    if (appointments.isEmpty) {
      return const Center(
        child: Text('لا توجد حجوزات مسجلة اليوم', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      );
    }

    return ListView.separated(
      itemCount: appointments.length > 5 ? 5 : appointments.length,
      separatorBuilder: (ctx, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final appt = appointments[index];
        return ListTile(
          dense: isCompact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          leading: const Icon(Icons.event, color: AppColors.secondary, size: 20),
          title: Text(appt['patient_name'] ?? 'مريض', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text('${appt['type'] ?? 'كشف'} - ${appt['time_slot'] ?? ''}', style: const TextStyle(fontSize: 11)),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Actions Logic
  // ═══════════════════════════════════════════════════════════════════════════

  void _onRegisterNewPatient() {
    if (!ShiftGuard.checkShiftOrWarn(context)) return;
    _showQuickRegisterDialog(context);
  }

  void _onBookAppointment() {
    if (!ShiftGuard.checkShiftOrWarn(context)) return;
    _showQuickBookAppointmentDialog(context);
  }

  void _showQuickRegisterDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AppDialog(
        title: 'تسجيل مريض جديد (استقبال سريعة)',
        subtitle: 'أدخل اسم المريض ورقم هاتفه للبدء والحجز',
        icon: Icons.person_add_alt_1_rounded,
        iconColor: AppColors.primary,
        maxWidth: 480,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'اسم المريض بالكامل *', prefixIcon: Icon(Icons.person)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم الهاتف *', prefixIcon: Icon(Icons.phone)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary))),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
              final res = await _viewModel.clinicCubit.addPatient({
                'name': nameCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'created_at': DateTime.now().toIso8601String(),
              });

              res.fold(
                (_) {},
                (_) {
                  _viewModel.clinicCubit.fetchPatients();
                },
              );

              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
            },
            child: const Text('حفظ المريض', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showQuickBookAppointmentDialog(BuildContext context) {
    final patients = _viewModel.clinicCubit.patients;
    if (patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('قم بتسجيل مريض أولاً لإمكانية الحجز'), backgroundColor: AppColors.error),
      );
      return;
    }

    int? selectedPatientId = patients.first['id'] as int?;
    String appointmentType = 'كشف جديد';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => AppDialog(
          title: 'حجز موعد جديد',
          subtitle: 'اختر المريض ونوع الكشف لتسجيل الموعد اليوم',
          icon: Icons.add_alarm_rounded,
          iconColor: AppColors.secondary,
          maxWidth: 480,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedPatientId,
                decoration: const InputDecoration(labelText: 'اختر المريض'),
                items: patients.map((p) {
                  return DropdownMenuItem<int>(
                    value: p['id'] as int,
                    child: Text('${p['name']} (${p['phone']})'),
                  );
                }).toList(),
                onChanged: (val) => setModalState(() => selectedPatientId = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: appointmentType,
                decoration: const InputDecoration(labelText: 'نوع الموعد / الكشف'),
                items: (_viewModel.clinicCubit.services.isNotEmpty
                        ? _viewModel.clinicCubit.services.map((s) => (s['name'] ?? '').toString()).toList()
                        : ['كشف جديد', 'إعادة / استشارة', 'متابعة نتيجه تحاليل'])
                    .map((typeStr) => DropdownMenuItem(value: typeStr, child: Text(typeStr)))
                    .toList(),
                onChanged: (val) => setModalState(() => appointmentType = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary))),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
              onPressed: () async {
                if (selectedPatientId == null) return;
                await _viewModel.clinicCubit.bookAppointment({
                  'patient_id': selectedPatientId,
                  'appointment_date': DateTime.now().toIso8601String().split('T')[0],
                  'time_slot': '10:00 AM',
                  'type': AppointmentType.fromString(appointmentType).dbValue,
                  'status': AppointmentStatus.waiting.dbValue,
                  'fee': 200.0,
                });

                _viewModel.clinicCubit.fetchWaitingQueue();
                _viewModel.clinicCubit.fetchAppointments();

                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              },
              child: const Text('تأكيد الحجز', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiData(this.title, this.value, this.icon, this.color);
}
