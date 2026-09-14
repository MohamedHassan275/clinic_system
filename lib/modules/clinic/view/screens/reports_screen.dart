import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../shared/cubit/block_builder_widget.dart';
import '../../data/cubit/clinic_cubit.dart';
import '../clinic_view_model.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final ClinicViewModel _viewModel;
  String _selectedPeriod = 'الكل';

  static const List<String> _periods = ['اليوم', 'هذا الأسبوع', 'هذا الشهر', 'الكل'];

  @override
  void initState() {
    super.initState();
    _viewModel = sl<ClinicViewModel>()..updateRefresh(() {
      if (mounted) setState(() {});
    });
    _viewModel.clinicCubit.fetchReports();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _exportPdfReport() async {
    final r = _viewModel.clinicCubit.reportsData;
    final pdf = pw.Document();

    final double grossRev = (r['grossRevenue'] as num?)?.toDouble() ?? 0.0;
    final double refunds = (r['totalRefunds'] as num?)?.toDouble() ?? 0.0;
    final double netRev = (r['netRevenue'] as num?)?.toDouble() ?? 0.0;
    final int totalAppts = r['totalAppointments'] ?? 0;
    final int completedAppts = r['completedAppointments'] ?? 0;
    final int cancelledAppts = r['cancelledAppointments'] ?? 0;
    final int totalPatients = r['totalPatients'] ?? 0;
    final int lowStock = r['lowStockItems'] ?? 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Comprehensive Clinic Financial & Operational Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.Text(DateTime.now().toIso8601String().substring(0, 10), style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text('Report Period: $_selectedPeriod', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                pw.SizedBox(height: 20),

                // Financial Section
                pw.Text('1. Financial Revenue Breakdown:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Bullet(text: 'Gross Revenue: ${grossRev.toStringAsFixed(2)} EGP'),
                pw.Bullet(text: 'Total Refunds Deducted: ${refunds.toStringAsFixed(2)} EGP'),
                pw.Bullet(text: 'Net Financial Collections: ${netRev.toStringAsFixed(2)} EGP'),
                pw.SizedBox(height: 16),

                // Operational Section
                pw.Text('2. Operational & Appointment Metrics:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Bullet(text: 'Total Registered Appointments: $totalAppts'),
                pw.Bullet(text: 'Completed Appointments: $completedAppts'),
                pw.Bullet(text: 'Cancelled Appointments: $cancelledAppts'),
                pw.Bullet(text: 'Total Registered Patients: $totalPatients'),
                pw.Bullet(text: 'Low Stock Inventory Alert Items: $lowStock'),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'clinic_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlockBuilderWidget<ClinicCubit, ClinicApiType>(
        types: const [ClinicApiType.getReports],
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
  // 1. Desktop Layout (>= 1024px)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopLayout() {
    final r = _viewModel.clinicCubit.reportsData;

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
                  Text('التقارير والإحصائيات الشاملة', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('تحليل الإيرادات الصافية، كفاءة التشغيل، ونسب إكمال الكشوفات', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
              Row(
                children: [
                  _buildPeriodSelector(),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _exportPdfReport,
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 18),
                    label: const Text('تصدير PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Top Summary KPI Row
          _buildKpiMetricsRow(r, isMobile: false, isTablet: false),
          const SizedBox(height: 20),

          // 2-Column Split View for Analytics
          Expanded(
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Column 1: Financial Analytics Card
                  Expanded(
                    child: _buildFinancialAnalyticsCard(r),
                  ),
                  const SizedBox(width: 16),
                  // Column 2: Operational Efficiency Card
                  Expanded(
                    child: _buildOperationalAnalyticsCard(r),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. Tablet Layout (600px - 1023px)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTabletLayout() {
    final r = _viewModel.clinicCubit.reportsData;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('التقارير والإحصائيات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('تحليل الإيرادات والكفاءة', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _exportPdfReport,
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 16),
                label: const Text('تصدير PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPeriodSelector(),
          const SizedBox(height: 12),
          _buildKpiMetricsRow(r, isMobile: false, isTablet: true),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildFinancialAnalyticsCard(r),
                  const SizedBox(height: 12),
                  _buildOperationalAnalyticsCard(r),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. Mobile Layout (< 600px)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout() {
    final r = _viewModel.clinicCubit.reportsData;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('تقارير العيادة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _exportPdfReport,
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 16),
                label: const Text('PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildPeriodSelector(),
          const SizedBox(height: 10),
          _buildKpiMetricsRow(r, isMobile: true, isTablet: false),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildFinancialAnalyticsCard(r),
                  const SizedBox(height: 10),
                  _buildOperationalAnalyticsCard(r),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helper Widgets & Cards
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPeriodSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _periods.map((p) {
          final isSelected = _selectedPeriod == p;
          return Padding(
            padding: const EdgeInsets.only(left: 6.0),
            child: ChoiceChip(
              selected: isSelected,
              label: Text(p, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : AppColors.textPrimary)),
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              onSelected: (val) {
                if (val) setState(() => _selectedPeriod = p);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKpiMetricsRow(Map<String, dynamic> r, {required bool isMobile, required bool isTablet}) {
    final double netRevenue = (r['netRevenue'] as num?)?.toDouble() ?? 0.0;
    final int totalAppts = r['totalAppointments'] ?? 0;
    final int totalPatients = r['totalPatients'] ?? 0;
    final int lowStock = r['lowStockItems'] ?? 0;

    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildKpiCard('صافي الإيرادات', '${netRevenue.toStringAsFixed(0)} ج.م', Icons.monetization_on_rounded, AppColors.success, 140),
            const SizedBox(width: 8),
            _buildKpiCard('المواعيد', '$totalAppts موعد', Icons.event_available_rounded, AppColors.primary, 130),
            const SizedBox(width: 8),
            _buildKpiCard('مرضى العيادة', '$totalPatients مريض', Icons.people_rounded, AppColors.secondary, 130),
            const SizedBox(width: 8),
            _buildKpiCard('النواقص', '$lowStock صنف', Icons.warning_rounded, AppColors.error, 120),
          ],
        ),
      );
    }

    if (isTablet) {
      return Row(
        children: [
          Expanded(child: _buildKpiCard('صافي الإيرادات', '${netRevenue.toStringAsFixed(0)} ج.م', Icons.monetization_on_rounded, AppColors.success, null)),
          const SizedBox(width: 8),
          Expanded(child: _buildKpiCard('المواعيد', '$totalAppts موعد', Icons.event_available_rounded, AppColors.primary, null)),
          const SizedBox(width: 8),
          Expanded(child: _buildKpiCard('مرضى العيادة', '$totalPatients مريض', Icons.people_rounded, AppColors.secondary, null)),
          const SizedBox(width: 8),
          Expanded(child: _buildKpiCard('النواقص', '$lowStock صنف', Icons.warning_rounded, AppColors.error, null)),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: _buildKpiCard('صافي الإيرادات الصافية', '${netRevenue.toStringAsFixed(0)} ج.م', Icons.monetization_on_rounded, AppColors.success, null)),
        const SizedBox(width: 12),
        Expanded(child: _buildKpiCard('إجمالي المواعيد المسجلة', '$totalAppts موعد', Icons.event_available_rounded, AppColors.primary, null)),
        const SizedBox(width: 12),
        Expanded(child: _buildKpiCard('مرضى العيادة المسجلين', '$totalPatients مريض', Icons.people_rounded, AppColors.secondary, null)),
        const SizedBox(width: 12),
        Expanded(child: _buildKpiCard('نواقص المستلزمات الطبية', '$lowStock صنف', Icons.warning_rounded, AppColors.error, null)),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color, double? width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialAnalyticsCard(Map<String, dynamic> r) {
    final double grossRevenue = (r['grossRevenue'] as num?)?.toDouble() ?? 0.0;
    final double refunds = (r['totalRefunds'] as num?)?.toDouble() ?? 0.0;
    final double netRevenue = (r['netRevenue'] as num?)?.toDouble() ?? 0.0;
    final double cashRevenue = (r['cashRevenue'] as num?)?.toDouble() ?? 0.0;
    final double cardRevenue = (r['cardRevenue'] as num?)?.toDouble() ?? 0.0;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text('التحليل المالي وطرق التحصيل', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),
            _buildStatRow('إجمالي المبالغ المحصلة (Gross)', '${grossRevenue.toStringAsFixed(1)} ج.م', Colors.blue[900]!),
            const SizedBox(height: 8),
            _buildStatRow('إجمالي الاسترجاعات والخصومات (-)', '${refunds.toStringAsFixed(1)} ج.م', AppColors.error),
            const SizedBox(height: 8),
            _buildStatRow('صافي الدخل المالي المتاح (Net)', '${netRevenue.toStringAsFixed(1)} ج.م', AppColors.success, isBold: true),
            const Divider(height: 20),
            const Text('توزيع المبالغ حسب طريقة الدفع:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            _buildStatRow('تحصيل كاش / نقدي (Cash)', '${cashRevenue.toStringAsFixed(1)} ج.م', AppColors.textPrimary),
            const SizedBox(height: 6),
            _buildStatRow('تحصيل فيزا / إلكتروني (Card)', '${cardRevenue.toStringAsFixed(1)} ج.م', AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationalAnalyticsCard(Map<String, dynamic> r) {
    final int totalAppts = r['totalAppointments'] ?? 0;
    final int completedAppts = r['completedAppointments'] ?? 0;
    final int cancelledAppts = r['cancelledAppointments'] ?? 0;
    final double attendanceRate = totalAppts > 0 ? ((completedAppts / totalAppts) * 100) : 0.0;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.insights_rounded, color: AppColors.secondary, size: 20),
                SizedBox(width: 8),
                Text('كفاءة التشغيل وحضور الحالات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),
            _buildStatRow('إجمالي المواعيد المحجوزة', '$totalAppts موعد', AppColors.textPrimary),
            const SizedBox(height: 8),
            _buildStatRow('الكشوفات المكتملة المنتهية (Completed)', '$completedAppts موعد', AppColors.success),
            const SizedBox(height: 8),
            _buildStatRow('المواعيد الملعاة (Cancelled)', '$cancelledAppts موعد', AppColors.error),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('نسبة الحضور والإكمال:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text('${attendanceRate.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: totalAppts > 0 ? (completedAppts / totalAppts) : 0.0,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: isBold ? AppColors.textPrimary : AppColors.textSecondary, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
      ],
    );
  }
}
