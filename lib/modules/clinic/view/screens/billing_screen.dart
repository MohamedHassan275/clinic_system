import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/common/widgets/app_dialog.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/enums/payment_enums.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/security/session_manager.dart';
import '../../../../core/security/shift_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../shared/cubit/block_builder_widget.dart';
import '../../../shift/view/shift_screen.dart';
import '../../data/cubit/clinic_cubit.dart';
import '../clinic_view_model.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  late final ClinicViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = sl<ClinicViewModel>()..updateRefresh(() {
      if (mounted) setState(() {});
    });
    _viewModel.clinicCubit.fetchInvoices();
    _viewModel.clinicCubit.fetchPatients();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _onCreateInvoiceClick() {
    final hasShift = ShiftGuard.checkShiftOrWarn(
      context,
      onNavigateToShift: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShiftScreen()));
      },
    );

    if (hasShift) {
      _showCreateInvoiceDialog(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlockBuilderWidget<ClinicCubit, ClinicApiType>(
        types: const [ClinicApiType.getInvoices, ClinicApiType.createInvoice],
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
  // 1. Desktop Layout (>= 1024px) — Workspace Split View
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopLayout() {
    final invoices = _viewModel.clinicCubit.invoices;

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
                  Text('الحسابات والفواتير والتحصيل', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('إصدار الفواتير المالية، تحصيل مبالغ الكشف، ومطابقة صندوق الوردية', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _onCreateInvoiceClick,
                icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
                label: const Text('إصدار فاتورة جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Shift Info Banner
          _buildActiveShiftCard(),
          const SizedBox(height: 16),

          // KPI Summary Row
          _buildKpiSummaryRow(isMobile: false),
          const SizedBox(height: 16),

          // Main Workspace Split View
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Panel (65%): Invoices Master Table
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
                              const Text('سجل الفواتير والمقبوضات الصادرة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(
                                'إجمالي الفواتير: ${invoices.length}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Expanded(child: _buildInvoicesListView(invoices)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Right Panel (35%): Shift Balance & Payment Method Breakdown
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
                                  Icon(Icons.pie_chart_outline_rounded, color: AppColors.primary, size: 20),
                                  SizedBox(width: 8),
                                  Text('توزيع المقبوضات وسندات الدفع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildPaymentMethodBreakdown(),
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
  // 2. Tablet Layout (600px - 1023px) — Grid View
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTabletLayout() {
    final invoices = _viewModel.clinicCubit.invoices;

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
                  Text('الحسابات والفواتير والتحصيل', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('إصدار الفواتير ومطابقة صندوق الوردية', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _onCreateInvoiceClick,
                icon: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
                label: const Text('فاتورة جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildActiveShiftCard(),
          const SizedBox(height: 14),
          _buildKpiSummaryRow(isMobile: true),
          const SizedBox(height: 14),
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: _buildInvoicesListView(invoices),
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
    final invoices = _viewModel.clinicCubit.invoices;

    return Padding(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الحسابات والفواتير والتحصيل', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('تحصيل المبالغ وإصدار إيصالات السداد بالعيادة', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _onCreateInvoiceClick,
              icon: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
              label: const Text('إصدار فاتورة جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 14),
          _buildActiveShiftCard(),
          const SizedBox(height: 14),
          _buildKpiSummaryRow(isMobile: true),
          const SizedBox(height: 14),
          Expanded(
            child: _buildInvoicesListView(invoices),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Shared Sub-Widgets
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildActiveShiftCard() {
    final activeShift = SessionManager.instance.activeShift;
    if (activeShift == null) return const SizedBox.shrink();

    return Card(
      color: AppColors.primaryLight,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'الوردية الحالية #${activeShift['id']}: النقدية الافتتاحية ${activeShift['starting_cash']} ج.م',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShiftScreen()));
              },
              icon: const Icon(Icons.settings, size: 16, color: AppColors.primary),
              label: const Text('إدارة الوردية', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiSummaryRow({bool isMobile = false}) {
    final list = _viewModel.clinicCubit.invoices;

    double totalRevenue = 0.0;
    double cashTotal = 0.0;
    double digitalTotal = 0.0;

    for (var inv in list) {
      final double paid = (inv['paid_amount'] as num?)?.toDouble() ?? 0.0;
      final double refunded = (inv['refunded_amount'] as num?)?.toDouble() ?? 0.0;
      final double netPaid = paid - refunded;

      totalRevenue += netPaid;

      final method = PaymentMethod.fromString(inv['payment_method'] as String?);
      final double invCash = (inv['cash_amount'] as num?)?.toDouble() ?? (method == PaymentMethod.cash ? paid : 0.0);
      final double invCard = (inv['card_amount'] as num?)?.toDouble() ?? (method != PaymentMethod.cash && method != PaymentMethod.cash ? paid : 0.0);

      final double ratio = paid > 0 ? (netPaid / paid) : 1.0;
      cashTotal += (invCash * ratio);
      digitalTotal += (invCard * ratio);
    }

    final items = [
      _KpiItem('إجمالي التحصيل', '${totalRevenue.toStringAsFixed(0)} ج.م', Icons.monetization_on_rounded, AppColors.success),
      _KpiItem('عدد الفواتير', list.length.toString(), Icons.receipt_long, AppColors.primary),
      _KpiItem('النقدي (كاش)', '${cashTotal.toStringAsFixed(0)} ج.م', Icons.payments_rounded, Colors.amber),
      _KpiItem('إلكتروني/تأمين', '${digitalTotal.toStringAsFixed(0)} ج.م', Icons.credit_card_rounded, Colors.purple),
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
                    Text(kpi.value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kpi.color)),
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
                      Text(kpi.value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kpi.color)),
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

  Widget _buildPaymentMethodBreakdown() {
    final list = _viewModel.clinicCubit.invoices;

    int cashCount = 0;
    int cardCount = 0;
    int transferCount = 0;
    int insuranceCount = 0;

    for (var inv in list) {
      final method = PaymentMethod.fromString(inv['payment_method'] as String?);
      switch (method) {
        case PaymentMethod.split:
          cashCount++;
          cardCount++;
          break;
        case PaymentMethod.cash:
          cashCount++;
          break;
        case PaymentMethod.card:
          cardCount++;
          break;
        case PaymentMethod.transfer:
          transferCount++;
          break;
        case PaymentMethod.insurance:
          insuranceCount++;
          break;
      }
    }

    return Column(
      children: [
        _buildBreakdownItem('دفع نقدي (كاش)', cashCount, Colors.amber, Icons.payments),
        const SizedBox(height: 8),
        _buildBreakdownItem('بطاقة إلكترونية / فيزا', cardCount, AppColors.primary, Icons.credit_card),
        const SizedBox(height: 8),
        _buildBreakdownItem('تحويل بنكي', transferCount, Colors.purple, Icons.account_balance),
        const SizedBox(height: 8),
        _buildBreakdownItem('تأمين صحي / تعاقد', insuranceCount, AppColors.success, Icons.health_and_safety),
      ],
    );
  }

  Widget _buildBreakdownItem(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicesListView(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textLight),
            const SizedBox(height: 12),
            const Text('لا توجد فواتير أو مقبوضات صادرة حتى الآن', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: _onCreateInvoiceClick,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('إصدار فاتورة جديدة', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final inv = list[index];
        final paymentEnum = PaymentMethod.fromString(inv['payment_method'] as String?);

        final double paid = (inv['paid_amount'] as num?)?.toDouble() ?? 0.0;
        final double refunded = (inv['refunded_amount'] as num?)?.toDouble() ?? 0.0;
        final double netPaid = paid - refunded;
        final String statusStr = inv['status'] as String? ?? 'paid';

        Color methodColor = AppColors.success;
        if (paymentEnum == PaymentMethod.card) methodColor = AppColors.primary;
        if (paymentEnum == PaymentMethod.transfer) methodColor = Colors.purple;
        if (paymentEnum == PaymentMethod.insurance) methodColor = Colors.teal;

        Color invoiceStatusColor = AppColors.success;
        String invoiceStatusLabel = 'مسددة ✅';
        if (statusStr == 'partially_refunded') {
          invoiceStatusColor = Colors.orange;
          invoiceStatusLabel = 'استرجاع جزئي ⚠️';
        } else if (statusStr == 'refunded' || netPaid <= 0) {
          invoiceStatusColor = AppColors.error;
          invoiceStatusLabel = 'مسترجعة 🔄';
        }

        return Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: methodColor.withValues(alpha: 0.15),
              child: Icon(Icons.receipt_outlined, color: methodColor, size: 20),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'فاتورة #${inv['id']} - ${inv['patient_name'] ?? 'مريض بدون اسم'}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: invoiceStatusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    invoiceStatusLabel,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: invoiceStatusColor),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: methodColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    paymentEnum.displayName,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: methodColor),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              'الإجمالي: ${inv['total_amount']} ج.م | الخصم: ${inv['discount']} ج.م | المسترجع: $refunded ج.م',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${netPaid.toStringAsFixed(0)} ج.م',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: netPaid <= 0 ? AppColors.error : AppColors.success),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'خيارات الفاتورة',
                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                  onSelected: (action) {
                    if (action == 'print') _printInvoiceReceipt(inv);
                    if (action == 'whatsapp') _sendWhatsAppInvoice(inv);
                    if (action == 'details') _showInvoiceDetailsModal(inv);
                    if (action == 'refund') _showRefundInvoiceDialog(inv);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'print',
                      child: Row(
                        children: [
                          Icon(Icons.print_outlined, color: Colors.purple, size: 18),
                          SizedBox(width: 8),
                          Text('طباعة الإيصال (Print)'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'whatsapp',
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, color: Colors.green, size: 18),
                          SizedBox(width: 8),
                          Text('إرسال عبر الواتساب (WhatsApp)'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'details',
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text('تفاصيل الفاتورة (Details)'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'refund',
                      child: Row(
                        children: [
                          Icon(Icons.assignment_return_outlined, color: AppColors.error, size: 18),
                          SizedBox(width: 8),
                          Text('استرجاع (Refund)'),
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

  void _showCreateInvoiceDialog(BuildContext context) {
    final patients = _viewModel.clinicCubit.patients;
    int? selectedPatientId = patients.isNotEmpty ? patients.first['id'] as int : null;
    final totalCtrl = TextEditingController();
    final discountCtrl = TextEditingController();
    final paidCtrl = TextEditingController();
    final cashPortionCtrl = TextEditingController();
    final cardPortionCtrl = TextEditingController();
    PaymentMethod selectedMethod = PaymentMethod.cash;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          title: 'إصدار فاتورة وتحصيل جديد',
          subtitle: 'أدخل تفاصيل تحصيل المبالغ المالية والخصومات الصادرة',
          icon: Icons.receipt_long_rounded,
          iconColor: AppColors.primary,
          maxWidth: 540,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (patients.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('ملاحظة: سيتم تسجيل الفاتورة لحساب مريض عام بالعيادة.', style: TextStyle(fontSize: 12, color: Colors.amber)),
                ),

              if (patients.isNotEmpty) ...[
                DropdownButtonFormField<int>(
                  initialValue: selectedPatientId,
                  decoration: InputDecoration(
                    labelText: 'اسم المريض *',
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

              // Payment Method Dropdown (Enum based)
              DropdownButtonFormField<PaymentMethod>(
                initialValue: selectedMethod,
                decoration: InputDecoration(
                  labelText: 'طريقة الدفع والتحصيل *',
                  prefixIcon: const Icon(Icons.payment_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: PaymentMethod.values.map((m) {
                  return DropdownMenuItem(value: m, child: Text(m.displayName));
                }).toList(),
                onChanged: (val) {
                  setDialogState(() {
                    selectedMethod = val!;
                    if (selectedMethod == PaymentMethod.split) {
                      final net = double.tryParse(paidCtrl.text) ?? 300.0;
                      cashPortionCtrl.text = (net / 2).toStringAsFixed(0);
                      cardPortionCtrl.text = (net / 2).toStringAsFixed(0);
                    }
                  });
                },
              ),
              const SizedBox(height: 14),

              // Total Amount
              TextField(
                controller: totalCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'المبلغ الإجمالي (ج.م) *',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (val) {
                  final total = double.tryParse(val) ?? 0;
                  final discount = double.tryParse(discountCtrl.text) ?? 0;
                  final net = (total - discount).clamp(0, double.infinity);
                  paidCtrl.text = net.toStringAsFixed(0);
                  if (selectedMethod == PaymentMethod.split) {
                    cashPortionCtrl.text = (net / 2).toStringAsFixed(0);
                    cardPortionCtrl.text = (net / 2).toStringAsFixed(0);
                  }
                },
              ),
              const SizedBox(height: 14),

              // Discount Amount
              TextField(
                controller: discountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'قيمة الخصم (ج.م)',
                  prefixIcon: const Icon(Icons.discount_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (val) {
                  final total = double.tryParse(totalCtrl.text) ?? 0;
                  final discount = double.tryParse(val) ?? 0;
                  final net = (total - discount).clamp(0, double.infinity);
                  paidCtrl.text = net.toStringAsFixed(0);
                  if (selectedMethod == PaymentMethod.split) {
                    cashPortionCtrl.text = (net / 2).toStringAsFixed(0);
                    cardPortionCtrl.text = (net / 2).toStringAsFixed(0);
                  }
                },
              ),
              const SizedBox(height: 14),

              // Net Paid Amount
              TextField(
                controller: paidCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'المبلغ المدفوع فعلياً (ج.م) *',
                  prefixIcon: const Icon(Icons.price_check_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              // Split Payment Fields
              if (selectedMethod == PaymentMethod.split) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('توزيع الدفع المجزأ (Split Payment):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: cashPortionCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'الجزء النقدي (كاش)',
                                prefixIcon: const Icon(Icons.payments, color: Colors.amber),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (val) {
                                final netPaid = double.tryParse(paidCtrl.text) ?? 0;
                                final cashVal = double.tryParse(val) ?? 0;
                                cardPortionCtrl.text = (netPaid - cashVal).clamp(0, double.infinity).toStringAsFixed(0);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: cardPortionCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'جزء الكارت / الفيزا',
                                prefixIcon: const Icon(Icons.credit_card, color: AppColors.primary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (val) {
                                final netPaid = double.tryParse(paidCtrl.text) ?? 0;
                                final cardVal = double.tryParse(val) ?? 0;
                                cashPortionCtrl.text = (netPaid - cardVal).clamp(0, double.infinity).toStringAsFixed(0);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary))),
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
                final nowStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

                final totalPaid = double.tryParse(paidCtrl.text) ?? 300.0;
                double cashAmt = 0.0;
                double cardAmt = 0.0;

                if (selectedMethod == PaymentMethod.cash) {
                  cashAmt = totalPaid;
                  cardAmt = 0.0;
                } else if (selectedMethod == PaymentMethod.split) {
                  cashAmt = double.tryParse(cashPortionCtrl.text) ?? (totalPaid / 2);
                  cardAmt = double.tryParse(cardPortionCtrl.text) ?? (totalPaid / 2);
                } else {
                  cashAmt = 0.0;
                  cardAmt = totalPaid;
                }

                await _viewModel.clinicCubit.createInvoice({
                  'patient_id': selectedPatientId ?? 1,
                  'user_id': user != null ? user['id'] : 1,
                  'shift_id': shift != null ? shift['id'] : 1,
                  'total_amount': double.tryParse(totalCtrl.text) ?? 300.0,
                  'discount': double.tryParse(discountCtrl.text) ?? 0.0,
                  'paid_amount': totalPaid,
                  'cash_amount': cashAmt,
                  'card_amount': cardAmt,
                  'payment_method': selectedMethod.dbValue,
                  'created_at': nowStr,
                });

                if (dialogCtx.mounted) {
                  Navigator.of(dialogCtx).pop();
                }
                _viewModel.clinicCubit.fetchInvoices();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إصدار وتوثيق الفاتورة بنجاح!'), backgroundColor: AppColors.success),
                  );
                }
              },
              child: const Text('تأكيد وإصدار', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printInvoiceReceipt(Map<String, dynamic> inv) async {
    final pdf = pw.Document();
    final paymentEnum = PaymentMethod.fromString(inv['payment_method'] as String?);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('إيصال تحصيل نقدية', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 6),
              pw.Text('رقم الفاتورة: #${inv['id']}'),
              pw.Text('اسم المريض: ${inv['patient_name'] ?? 'مريض'}'),
              pw.Text('التاريخ: ${inv['created_at'] ?? ''}'),
              pw.Text('طريقة الدفع: ${paymentEnum.displayName}'),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('المبلغ الإجمالي:'),
                  pw.Text('${inv['total_amount']} ج.م'),
                ],
              ),
              if ((inv['discount'] as num? ?? 0) > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('الخصم الممنوح:'),
                    pw.Text('${inv['discount']} ج.م'),
                  ],
                ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('المبلغ المدفوع:'),
                  pw.Text('${inv['paid_amount']} ج.م', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Divider(),
              pw.Center(child: pw.Text('شكراً لتعاملكم معنا')),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'invoice_${inv['id']}.pdf',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال إيصال السداد للطباعة بنجاح!'), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _sendWhatsAppInvoice(Map<String, dynamic> inv) async {
    final phone = inv['patient_phone'] ?? '01000000000';
    final patientName = inv['patient_name'] ?? 'عزيزي المريض';
    final invId = inv['id'];
    final paidAmount = inv['paid_amount'];
    final method = PaymentMethod.fromString(inv['payment_method'] as String?).displayName;
    final date = inv['created_at'] ?? '';

    final message = 'أهلاً بك $patientName، تم إصدار إيصال تحصيل رقم #$invId بمبلغ $paidAmount ج.م ($method) بتاريخ $date. شكراً لتعاملكم معنا.';
    final encoded = Uri.encodeComponent(message);
    final cleanPhone = phone.toString().replaceAll(RegExp(r'\D'), '');
    final formattedPhone = cleanPhone.startsWith('0') ? '2$cleanPhone' : cleanPhone;
    final url = Uri.parse('https://wa.me/$formattedPhone?text=$encoded');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم فتح الواتساب لإرسال الإيصال إلى $phone'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل فتح الواتساب: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showInvoiceDetailsModal(Map<String, dynamic> inv) {
    final paymentEnum = PaymentMethod.fromString(inv['payment_method'] as String?);

    showDialog(
      context: context,
      builder: (dialogCtx) => AppDialog(
        title: 'تفاصيل الفاتورة #${inv['id']}',
        subtitle: 'بيانات الفاتورة الصادرة للمريض: ${inv['patient_name'] ?? ''}',
        icon: Icons.receipt_long,
        iconColor: AppColors.primary,
        content: Column(
          children: [
            _buildDetailRow('رقم الفاتورة:', '#${inv['id']}'),
            _buildDetailRow('اسم المريض:', '${inv['patient_name'] ?? ''}'),
            _buildDetailRow('طريقة الدفع:', paymentEnum.displayName),
            _buildDetailRow('المبلغ الإجمالي:', '${inv['total_amount']} ج.م'),
            _buildDetailRow('الخصم:', '${inv['discount']} ج.م'),
            _buildDetailRow('المدفوع فعلياً:', '${inv['paid_amount']} ج.م'),
            _buildDetailRow('تاريخ الإصدار:', '${inv['created_at'] ?? ''}'),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('إغلاق', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  void _showRefundInvoiceDialog(Map<String, dynamic> inv) {
    final double originalPaid = (inv['paid_amount'] as num?)?.toDouble() ?? 0.0;
    final double alreadyRefunded = (inv['refunded_amount'] as num?)?.toDouble() ?? 0.0;
    final double maxRefundable = (originalPaid - alreadyRefunded).clamp(0, double.infinity);

    if (maxRefundable <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذه الفاتورة مسترجعة بالكامل بالفعل!'), backgroundColor: AppColors.error),
      );
      return;
    }

    final refundAmountCtrl = TextEditingController(text: maxRefundable.toStringAsFixed(0));
    final reasonCtrl = TextEditingController(text: 'طلب المريض إلغاء الخدمة / استرجاع الكشف');

    showDialog(
      context: context,
      builder: (dialogCtx) => AppDialog(
        title: 'استرجاع الفاتورة #${inv['id']}',
        subtitle: 'المريض: ${inv['patient_name']} | المبلغ الأقصى القابل للاسترجاع: $maxRefundable ج.م',
        icon: Icons.assignment_return_rounded,
        iconColor: AppColors.error,
        maxWidth: 480,
        content: Column(
          children: [
            TextField(
              controller: refundAmountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'المبلغ المسترجع (ج.م) *',
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'سبب الاسترجاع *',
                prefixIcon: const Icon(Icons.notes),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              final amount = double.tryParse(refundAmountCtrl.text) ?? 0.0;
              if (amount <= 0 || amount > maxRefundable) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('يرجى إدخال مبلغ استرجاع صحيح (بين 1 و $maxRefundable)'), backgroundColor: AppColors.error),
                );
                return;
              }

              await _viewModel.clinicCubit.refundInvoice(
                invoiceId: inv['id'] as int,
                refundAmount: amount,
                reason: reasonCtrl.text.trim(),
                patientId: inv['patient_id'] as int,
              );

              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم استرجاع مبلغ $amount ج.م وتخفيض رصيد الخزينة بالوردية!'), backgroundColor: AppColors.success),
                );
              }
            },
            child: const Text('تأكيد الاسترجاع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
