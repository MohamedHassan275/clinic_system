import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../shared/cubit/block_builder_widget.dart';
import '../../data/cubit/clinic_cubit.dart';
import '../clinic_view_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final ClinicViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = sl<ClinicViewModel>()..updateRefresh(() {
      if (mounted) setState(() {});
    });
    _viewModel.clinicCubit.fetchDashboardStats();
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نظرة عامة على العيادة اليوم',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'متابعة الحجوزات، غرفة الانتظار، والإيرادات المالية المباشرة',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'تحديث البيانات',
                  onPressed: () => _viewModel.clinicCubit.fetchDashboardStats(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            BlockBuilderWidget<ClinicCubit, ClinicApiType>(
              types: const [ClinicApiType.getDashboard],
              body: (_) => _buildStatsGrid(),
              loading: (_) => const Center(child: CircularProgressIndicator()),
            ),
            const SizedBox(height: 32),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 900) {
                  return const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _QuickInfoCard(
                          title: 'مؤشر الحجوزات الأسبوعي',
                          icon: Icons.bar_chart_rounded,
                          contentText: 'يتم احتساب إحصائيات المواعيد الأسبوعية تلقائياً بناءً على سجلات العيادة المفعلة في SQLite',
                        ),
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        flex: 2,
                        child: _QuickInfoCard(
                          title: 'تنبيهات النظام والمواعيد',
                          icon: Icons.notifications_active_rounded,
                          contentText: 'حالة الوردية والنظام متزنة ولا توجد تنبيهات عاجلة متأخرة حالياً',
                        ),
                      ),
                    ],
                  );
                } else {
                  return const Column(
                    children: [
                      _QuickInfoCard(
                        title: 'مؤشر الحجوزات الأسبوعي',
                        icon: Icons.bar_chart_rounded,
                        contentText: 'يتم احتساب إحصائيات المواعيد الأسبوعية تلقائياً بناءً على سجلات العيادة المفعلة في SQLite',
                      ),
                      SizedBox(height: 16),
                      _QuickInfoCard(
                        title: 'تنبيهات النظام والمواعيد',
                        icon: Icons.notifications_active_rounded,
                        contentText: 'حالة الوردية والنظام متزنة ولا توجد تنبيهات عاجلة متأخرة حالياً',
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = _viewModel.clinicCubit.dashboardStats;
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1100 ? 4 : (constraints.maxWidth > 650 ? 2 : 1);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _StatCard(
              title: 'مواعيد اليوم',
              value: '${stats['todayAppointments'] ?? 0}',
              icon: Icons.calendar_month_rounded,
              color: AppColors.primary,
            ),
            _StatCard(
              title: 'المرضى في الانتظار',
              value: '${stats['waitingCount'] ?? 0}',
              icon: Icons.access_time_filled_rounded,
              color: Colors.amber[800]!,
            ),
            _StatCard(
              title: 'إجمالي ملفات المرضى',
              value: '${stats['totalPatients'] ?? 0}',
              icon: Icons.people_alt_rounded,
              color: AppColors.secondary,
            ),
            _StatCard(
              title: 'إيرادات تحصيل اليوم',
              value: '${stats['todayRevenue'] ?? 0.0} ج.م',
              icon: Icons.account_balance_wallet_rounded,
              color: AppColors.success,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
              ],
            ),
            Text(
              value,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickInfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String contentText;

  const _QuickInfoCard({
    required this.title,
    required this.icon,
    required this.contentText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 120,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  contentText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
