import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/enums/appointment_enums.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/security/session_manager.dart';
import '../../../../core/security/shift_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../shared/cubit/block_builder_widget.dart';
import '../../../main_shell/view/main_shell_view_model.dart';
import '../../data/cubit/clinic_cubit.dart';
import '../clinic_view_model.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  late final ClinicViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = sl<ClinicViewModel>()..updateRefresh(() {
      if (mounted) setState(() {});
    });
    _viewModel.clinicCubit.fetchDashboardStats();
    _viewModel.clinicCubit.fetchWaitingQueue();
    _viewModel.clinicCubit.fetchAppointments();
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
          ClinicApiType.getDashboard,
          ClinicApiType.getWaitingRoom,
          ClinicApiType.getAppointments,
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
  // 1. Desktop Layout (>= 1024px) — Split View Dashboard
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
                // Right Side (65%): Today's Active Consultation Queue
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
                            title: 'قائمة كشوفات وانتظار اليوم',
                            subtitle: 'إدارة دخول المرضى لغرفة الكشف ومتابعة الحالات الحية',
                            icon: Icons.personal_injury_rounded,
                          ),
                          const SizedBox(height: 16),
                          Expanded(child: _buildQueueListView(isMobile: false)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // Left Side (35%): Doctor Shortcuts & Today's Summary
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      _buildDoctorActionsCard(),
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
                                  title: 'أحدث الروشتات الصادرة',
                                  subtitle: 'متابعة الروشتات التي تم حفظها اليوم',
                                  icon: Icons.receipt_long_rounded,
                                ),
                                const SizedBox(height: 12),
                                Expanded(child: _buildRecentPrescriptionsList()),
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
  // 2. Tablet Layout (600px - 1023px) — Dual Column Layout
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
                  flex: 6,
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            title: 'قائمة انتظار المرضى',
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
                  flex: 5,
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            title: 'أحدث الروشتات الصادرة',
                            icon: Icons.receipt_long_rounded,
                          ),
                          const SizedBox(height: 12),
                          Expanded(child: _buildRecentPrescriptionsList()),
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
  // 3. Mobile Layout (< 600px) — Stack View
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
            title: 'مرضى الانتظار والكشف',
            subtitle: 'متابعة قائمة اليوم',
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
            title: 'أحدث الروشتات الصادرة',
            icon: Icons.receipt_long_rounded,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 280,
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: _buildRecentPrescriptionsList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Shared Sub-Widgets
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader({required bool isMobile}) {
    final user = SessionManager.instance.currentUser;
    final String doctorName = user != null ? (user['full_name'] ?? 'دكتور العيادة') : 'دكتور العيادة';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'أهلاً بك، د. $doctorName 👋',
          style: TextStyle(
            fontSize: isMobile ? 18 : 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'لوحة تحكم الطبيب: متابعة الكشوفات، إدخال المرضى، وكتابة الروشتات الإلكترونية',
          style: TextStyle(
            fontSize: isMobile ? 12 : 13,
            color: AppColors.textSecondary,
          ),
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
    final stats = _viewModel.clinicCubit.dashboardStats;

    final int waitingCount = queue.where((q) => AppointmentStatus.fromString(q['status']).isWaiting).length;
    final int inConsultationCount = queue.where((q) => AppointmentStatus.fromString(q['status']).isInProgress).length;
    final int completedCount = queue.where((q) => AppointmentStatus.fromString(q['status']).isCompleted).length;
    final int totalToday = (stats['today_appointments'] as num?)?.toInt() ?? queue.length;

    final items = [
      _KpiData('إجمالي كشوفات اليوم', totalToday.toString(), Icons.calendar_today_rounded, AppColors.secondary),
      _KpiData('في الانتظار', waitingCount.toString(), Icons.hourglass_empty_rounded, Colors.amber),
      _KpiData('جاري الكشف', inConsultationCount.toString(), Icons.medical_services_outlined, AppColors.primary),
      _KpiData('الكشوفات المكتملة', completedCount.toString(), Icons.check_circle_outline, AppColors.success),
    ];

    if (isMobile) {
      return Row(
        children: items.map((kpi) {
          return Expanded(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Column(
                  children: [
                    Icon(kpi.icon, color: kpi.color, size: 18),
                    const SizedBox(height: 4),
                    Text(kpi.value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kpi.color)),
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

  Widget _buildDoctorActionsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              title: 'اختصارات الطبيب السريعة',
              subtitle: 'روابط التنقل الفوري',
              icon: Icons.flash_on_rounded,
            ),
            const SizedBox(height: 14),
            _buildActionButton(
              label: '🩺 الكشف والروشتة الإلكترونية',
              icon: Icons.medical_services_rounded,
              color: AppColors.primary,
              onPressed: () => sl<MainShellViewModel>().selectTabByKey('consultation'),
            ),
            const SizedBox(height: 10),
            _buildActionButton(
              label: '👤 البحث في ملفات المرضى (EMR)',
              icon: Icons.folder_shared_rounded,
              color: AppColors.secondary,
              onPressed: () => sl<MainShellViewModel>().selectTabByKey('emr'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButtonsBar({bool isMobile = false}) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            label: isMobile ? '🩺 الكشف' : '🩺 الكشف والروشتة الإلكترونية',
            icon: Icons.medical_services_rounded,
            color: AppColors.primary,
            onPressed: () => sl<MainShellViewModel>().selectTabByKey('consultation'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionButton(
            label: isMobile ? '👤 المرضى' : '👤 ملفات المرضى (EMR)',
            icon: Icons.folder_shared_rounded,
            color: AppColors.secondary,
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
            Text('لا يوجد مرضى في انتظار الكشف حالياً', style: TextStyle(color: AppColors.textSecondary)),
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
          subtitle: Text('نوع الكشف: ${apptType.displayName} | الوقت: ${item['time_slot'] ?? 'غير محدد'}', style: const TextStyle(fontSize: 12)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(apptStatus.displayName, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.medical_services_rounded, color: AppColors.primary, size: 20),
                tooltip: 'بدء الكشف والروشتة',
                onPressed: () async {
                  if (!ShiftGuard.checkShiftOrWarn(context)) return;
                  final int apptId = item['id'] as int;
                  if (apptStatus.isWaiting) {
                    await _viewModel.clinicCubit.checkInPatient(apptId);
                  }
                  sl<MainShellViewModel>().selectTabByKey('consultation');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentPrescriptionsList() {
    final appointments = _viewModel.clinicCubit.appointments;
    final completed = appointments.where((a) => AppointmentStatus.fromString(a['status']).isCompleted).toList();

    if (completed.isEmpty) {
      return const Center(
        child: Text('لا توجد كشوفات أو روشتات مكتملة اليوم حتى الآن', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      );
    }

    return ListView.separated(
      itemCount: completed.length > 5 ? 5 : completed.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = completed[index];
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          leading: const Icon(Icons.check_circle, color: AppColors.success, size: 18),
          title: Text(item['patient_name'] ?? 'مريض', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text('كشف مكتمل - ${item['time_slot'] ?? ''}', style: const TextStyle(fontSize: 11)),
        );
      },
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
