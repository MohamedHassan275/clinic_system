import 'package:flutter/material.dart';
import '../../../../core/common/widgets/app_dialog.dart';
import '../../../../core/di/service_locator.dart';
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
    final activeShift = SessionManager.instance.activeShift;
    final media = MediaQuery.of(context);
    final bool isMobile = media.size.width < 768;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 14.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isMobile) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الحسابات والفواتير والتحصيل', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('إصدار تحصيل مبالغ الكشف ومطابقة الوردية', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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
                      icon: const Icon(Icons.receipt, color: Colors.white, size: 20),
                      label: const Text('إصدار فاتورة جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ] else ...[
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
                    icon: const Icon(Icons.receipt, color: Colors.white),
                    label: const Text('إصدار فاتورة جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            if (activeShift != null) ...[
              Card(
                color: AppColors.primaryLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_wallet, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'مطابقة عهدة الوردية #${activeShift['id']}: النقدية الافتتاحية: ${activeShift['starting_cash']} ج.م',
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
                        icon: const Icon(Icons.settings, size: 18),
                        label: const Text('إدارة الوردية'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Expanded(
              child: BlockBuilderWidget<ClinicCubit, ClinicApiType>(
                types: const [ClinicApiType.getInvoices],
                body: (_) => _buildInvoicesTable(),
                loading: (_) => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicesTable() {
    final list = _viewModel.clinicCubit.invoices;
    if (list.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text('لا توجد فواتير صادرة حتى الآن')),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        itemCount: list.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final inv = list[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: AppColors.success.withValues(alpha: 0.15),
              child: const Icon(Icons.attach_money, color: AppColors.success),
            ),
            title: Text('فاتورة #${inv['id']} - ${inv['patient_name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text('المبلغ الإجمالي: ${inv['total_amount']} ج.م | الخصم: ${inv['discount']} ج.م | طريقة الدفع: ${inv['payment_method']}'),
            trailing: Text(
              'المدفوع: ${inv['paid_amount']} ج.م',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.success),
            ),
          );
        },
      ),
    );
  }

  void _showCreateInvoiceDialog(BuildContext context) {
    final patients = _viewModel.clinicCubit.patients;
    int? selectedPatientId = patients.isNotEmpty ? patients.first['id'] as int : null;
    final totalCtrl = TextEditingController(text: '300');
    final discountCtrl = TextEditingController(text: '0');
    final paidCtrl = TextEditingController(text: '300');
    String paymentMethod = 'نقدي (كاش)';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          title: 'إصدار فاتورة جديدة',
          subtitle: 'أدخل تفاصيل تحصيل المبالغ المالية والخصومات الصادرة',
          icon: Icons.receipt_long_rounded,
          iconColor: AppColors.primary,
          maxWidth: 500,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                    child: Text('${p['name']}'),
                  );
                }).toList(),
                onChanged: (val) => setDialogState(() => selectedPatientId = val),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: totalCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'المبلغ الإجمالي (ج.م) *',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: discountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'قيمة الخصم (ج.م)',
                  prefixIcon: const Icon(Icons.discount_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: paidCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'المبلغ المدفوع فعلياً (ج.م) *',
                  prefixIcon: const Icon(Icons.price_check_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
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
                final nowStr = DateTime.now().toIso8601String().substring(0, 10);

                await _viewModel.clinicCubit.createInvoice({
                  'patient_id': selectedPatientId ?? 1,
                  'user_id': user != null ? user['id'] : 1,
                  'shift_id': shift != null ? shift['id'] : 1,
                  'total_amount': double.tryParse(totalCtrl.text) ?? 300.0,
                  'discount': double.tryParse(discountCtrl.text) ?? 0.0,
                  'paid_amount': double.tryParse(paidCtrl.text) ?? 300.0,
                  'payment_method': paymentMethod,
                  'created_at': nowStr,
                });

                if (dialogCtx.mounted) {
                  Navigator.of(dialogCtx).pop();
                }
                _viewModel.clinicCubit.fetchInvoices();
              },
              child: const Text('إصدار الفاتورة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
