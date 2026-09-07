import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/security/session_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../shared/cubit/base_cubit.dart';
import '../data/cubit/shift_cubit.dart';
import 'shift_view_model.dart';
import '../../main_shell/view/clinic_main_shell.dart';
import '../../auth/view/login_screen.dart';

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
    _viewModel.checkInitialShift();
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

  void _navigateToLogin() {
    SessionManager.instance.clearSession();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionManager.instance.currentUser;
    final hasShift = SessionManager.instance.hasActiveShift;
    final activeShift = SessionManager.instance.activeShift;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('إدارة الورديات والتدفق المالي'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.error),
            tooltip: 'تسجيل الخروج',
            onPressed: _navigateToLogin,
          ),
        ],
      ),
      body: BlocProvider.value(
        value: _viewModel.shiftCubit,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isDesktop = constraints.maxWidth >= 900;
            if (isDesktop) {
              return Row(
                children: [
                  // Right Pane: Medical Shift Illustration & Value Points (45%)
                  Expanded(
                    flex: 45,
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.sidebarBackground, Color(0xFF1E3A8A)],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.all(36),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.point_of_sale_rounded, size: 56, color: AppColors.accent),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'إدارة الورديات وتدفقات الصندوق',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'نظام متكامل لتسجيل عهدة الصندوق، تتبع الوقت والتاريخ، ومطابقة إيرادات الكشوفات والفواتير بدقة فائقة.',
                            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.6),
                          ),
                          const SizedBox(height: 36),
                          _buildBrandingPoint('تسجيل وقت وتاريخ بدء الوردية بدقة'),
                          const SizedBox(height: 12),
                          _buildBrandingPoint('مطابقة العهدة النقدية الافتتاحية والختامية'),
                          const SizedBox(height: 12),
                          _buildBrandingPoint('حظر أية حجوزات أو فواتير بدون وردية مفعّلة'),
                        ],
                      ),
                    ),
                  ),
                  // Left Pane: Shift Card Form (55%)
                  Expanded(
                    flex: 55,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 580),
                          child: _buildShiftCard(user, hasShift, activeShift),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              // Mobile Layout: Single Column Centered
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: _buildShiftCard(user, hasShift, activeShift),
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildBrandingPoint(String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ),
      ],
    );
  }

  Widget _buildShiftCard(Map<String, dynamic>? user, bool hasShift, Map<String, dynamic>? activeShift) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hasShift ? AppColors.primaryLight : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    hasShift ? Icons.check_circle_rounded : Icons.access_time_filled_rounded,
                    color: hasShift ? AppColors.primary : Colors.orange[800],
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
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'المستخدم الحالي: ${user != null ? user['full_name'] : 'غير معروف'}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
                ),
                onPressed: () => _showCloseShiftDialog(context),
                icon: const Icon(Icons.lock_clock),
                label: const Text('إغلاق الوردية الحالية الآن'),
              ),
            ] else ...[
              const Text(
                'ملاحظة: لإنشاء الحجوزات وإصدار الفواتير والروشتات، يلزم بدء وردية مالية وتحديد عهدة الصندوق والوقت.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 20),
              // Date & Time Row above Cash input
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _viewModel.dateController,
                      enabled: false,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'تاريخ الوردية (ثابت)',
                        prefixIcon: Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _viewModel.timeController,
                      readOnly: true,
                      onTap: () => _viewModel.selectStartTime(context),
                      decoration: const InputDecoration(
                        labelText: 'وقت بدء الوردية',
                        prefixIcon: Icon(Icons.access_time_rounded, color: AppColors.secondary),
                        suffixIcon: Icon(Icons.arrow_drop_down),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _viewModel.startingCashController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'العهدة النقدية الافتتاحية للصندوق (ج.م)',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _viewModel.notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات إضافية عند بدء الوردية (اختياري)',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 24),
              _buildStartShiftButton(),
            ],
          ],
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
          _buildInfoRow('المستخدم مسؤول الوردية:', user != null ? user['full_name'] : 'غير معروف'),
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
        ),
        onPressed: () {
          _viewModel.startNewShift(
            onSuccess: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم بدء الوردية وحفظ البيانات في قاعدة البيانات بنجاح!'),
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('إغلاق الوردية المالية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('يرجى جرد الصندوق وإدخال المبلغ النهائي المتوفر:'),
            const SizedBox(height: 12),
            TextField(
              controller: _viewModel.endingCashController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'المبلغ الإجمالي في النقدية عند الإغلاق (ج.م)',
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
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
            child: const Text('تأكيد الإغلاق', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
