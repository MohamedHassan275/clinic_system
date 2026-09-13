import 'package:flutter/material.dart';
import '../../../../core/common/widgets/app_dialog.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/security/session_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../main_shell/view/clinic_main_shell.dart';
import '../../shared/cubit/base_cubit.dart';
import '../data/cubit/shift_cubit.dart';
import 'shift_view_model.dart';

class ShiftScreen extends StatefulWidget {
  const ShiftScreen({super.key});

  @override
  State<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends State<ShiftScreen> {
  late final ShiftViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = sl<ShiftViewModel>()..updateRefresh(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _navigateToMainShell() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ClinicMainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionManager.instance.currentUser;
    final activeShift = SessionManager.instance.activeShift;
    final bool hasShift = SessionManager.instance.hasActiveShift;
    final media = MediaQuery.of(context);
    final bool isMobile = media.size.width < 768;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('إدارة ورشات العمل والصندوق'),
        centerTitle: false,
        actions: [
          if (hasShift)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: _navigateToMainShell,
                icon: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 18),
                label: const Text('لوحة العيادة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 20.0 : 32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: hasShift ? AppColors.success.withValues(alpha: 0.15) : AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            hasShift ? Icons.check_circle_rounded : Icons.access_time_filled_rounded,
                            color: hasShift ? AppColors.success : AppColors.primary,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasShift ? 'الوردية الحالية نشطة ومفتوحة' : 'فتح وردية عمل جديدة',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'المستخدم الحالي: ${user != null ? (user['full_name'] ?? 'غير معروف') : 'غير معروف'}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 36),
                    if (hasShift && activeShift != null) ...[
                      _buildActiveShiftInfo(activeShift, user),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _navigateToMainShell,
                          icon: const Icon(Icons.dashboard_rounded, color: Colors.white),
                          label: const Text(
                            'الدخول إلى لوحة نظام العيادة',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          minimumSize: const Size(double.infinity, 46),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _showCloseShiftDialog(context),
                        icon: const Icon(Icons.lock_clock),
                        label: const Text('إغلاق الوردية الحالية الآن', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ] else ...[
                      const Text(
                        'ملاحظة: لإنشاء الحجوزات وإصدار الفواتير والروشتات، يلزم بدء وردية مالية وتحديد عهدة الصندوق والوقت.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _viewModel.dateController,
                              enabled: false,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'تاريخ الوردية (ثابت)',
                                prefixIcon: const Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _viewModel.timeController,
                              readOnly: true,
                              onTap: () => _viewModel.selectStartTime(context),
                              decoration: InputDecoration(
                                labelText: 'وقت بدء الوردية',
                                prefixIcon: const Icon(Icons.access_time_rounded, color: AppColors.secondary),
                                suffixIcon: const Icon(Icons.arrow_drop_down),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _viewModel.startingCashController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'العهدة النقدية الافتتاحية للصندوق (ج.م)',
                          prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _viewModel.notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'ملاحظات إضافية عند بدء الوردية (اختياري)',
                          prefixIcon: const Icon(Icons.notes_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildStartShiftButton(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveShiftInfo(Map<String, dynamic> shift, Map<String, dynamic>? user) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildInfoRow('المستخدم مسؤول الوردية:', user != null ? (user['full_name'] ?? 'غير معروف') : 'غير معروف'),
          const SizedBox(height: 10),
          _buildInfoRow('رقم الوردية:', '#${shift['id']}'),
          const SizedBox(height: 10),
          _buildInfoRow('تاريخ ووقت بدء الوردية:', shift['start_time'].toString().replaceAll('T', ' ')),
          const SizedBox(height: 10),
          _buildInfoRow('النقدية الافتتاحية للعهدية:', '${shift['starting_cash']} ج.م'),
          if (shift['notes'] != null && shift['notes'].toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildInfoRow('ملاحظات الوردية:', shift['notes'].toString()),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.left,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildStartShiftButton() {
    final isLoading = _viewModel.shiftCubit.stateOf(ShiftApiType.startShift).isLoading();

    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12.0),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () {
          _viewModel.startNewShift(
            onSuccess: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم بدء الوردية وحفظ البيانات بنجاح!'),
                  backgroundColor: AppColors.success,
                ),
              );
              if (mounted) setState(() {});
            },
            onError: (err) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(err), backgroundColor: AppColors.error),
              );
            },
          );
        },
        icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
        label: const Text(
          'بدء الوردية وتأكيد العهدة',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  void _showCloseShiftDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'إغلاق الوردية المالية',
        subtitle: 'يرجى جرد النقدية وإدخال المبلغ النهائي عند إغلاق الصندوق',
        icon: Icons.lock_clock_rounded,
        iconColor: AppColors.error,
        maxWidth: 460,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _viewModel.endingCashController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'المبلغ الإجمالي في النقدية عند الإغلاق (ج.م) *',
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _viewModel.closeCurrentShift(
                onSuccess: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إغلاق الوردية بنجاح.')),
                  );
                  if (mounted) setState(() {});
                },
                onError: (err) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err), backgroundColor: AppColors.error),
                  );
                },
              );
            },
            child: const Text('تأكيد الإغلاق', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
