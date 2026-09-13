import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../core/common/widgets/app_dialog.dart';
import '../../../../../core/enums/lab_enums.dart';
import '../../../../../core/security/shift_guard.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../data/cubit/clinic_cubit.dart';

class PatientLabResultsTabWidget extends StatelessWidget {
  final Map<String, dynamic>? selectedPatientRecord;
  final int patientId;
  final ClinicCubit cubit;

  const PatientLabResultsTabWidget({
    super.key,
    required this.selectedPatientRecord,
    required this.patientId,
    required this.cubit,
  });

  void _showAddLabResultDialog(BuildContext context) {
    if (!ShiftGuard.checkShiftOrWarn(context)) return;

    final testNameCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'mg/dL');
    final refCtrl = TextEditingController(text: '70-110');
    LabResultStatus status = LabResultStatus.normal;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AppDialog(
            title: 'إضافة نتيجة فحص معملي جديدة',
            subtitle: 'أدخل معلومات الفحص المعملي وتصنيف النتيجة',
            icon: Icons.science_rounded,
            iconColor: AppColors.primary,
            maxWidth: 500,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: testNameCtrl,
                  decoration: const InputDecoration(labelText: 'اسم الفحص / التحليل *', hintText: 'مثال: CBC, FBG, HbA1c'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: valueCtrl,
                        decoration: const InputDecoration(labelText: 'النتيجة المقاسة *'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: unitCtrl,
                        decoration: const InputDecoration(labelText: 'الوحدة *'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(labelText: 'المدى الطبيعي المرجعي (Reference Range)'),
                ),
                const SizedBox(height: 14),
                const Text('تصنيف الحالة السريرية للنتيجة (Status Flag):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: LabResultStatus.values.map((st) {
                    final bool isSel = status == st;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        child: ChoiceChip(
                          label: Text(st.displayName, style: TextStyle(color: isSel ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                          selected: isSel,
                          selectedColor: st == LabResultStatus.high ? AppColors.error : (st == LabResultStatus.low ? Colors.blue : AppColors.success),
                          onSelected: (val) {
                            if (val) setModalState(() => status = st);
                          },
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
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () async {
                  if (testNameCtrl.text.trim().isEmpty || valueCtrl.text.trim().isEmpty) return;

                  final labResultData = {
                    'patient_id': patientId,
                    'test_name': testNameCtrl.text.trim(),
                    'test_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                    'measured_value': valueCtrl.text.trim(),
                    'unit': unitCtrl.text.trim(),
                    'reference_range': refCtrl.text.trim(),
                    'status': status.dbValue,
                  };

                  await cubit.addLabResult(labResultData);
                  if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                },
                icon: const Icon(Icons.check, color: Colors.white, size: 18),
                label: const Text('حفظ النتيجة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labs = selectedPatientRecord != null ? (selectedPatientRecord!['lab_results'] as List? ?? []) : [];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Bar Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('نتائج التحاليل والفحوصات المعملية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('متابعة نتائج المختبر والمدى المرجعي والتصنيف السريري', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showAddLabResultDialog(context),
                icon: const Icon(Icons.science_rounded, color: Colors.white, size: 18),
                label: const Text('إضافة نتيجة جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Lab Results List
          Expanded(
            child: labs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.science_outlined, size: 48, color: AppColors.textLight),
                        const SizedBox(height: 12),
                        const Text('لا توجد نتائج فحوصات معملية مسجلة للمريض', style: TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          onPressed: () => _showAddLabResultDialog(context),
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text('إضافة نتيجة فحص', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: labs.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final lab = labs[index];
                      final statusEnum = LabResultStatus.fromString(lab['status'] as String?);

                      Color flagColor = AppColors.success;
                      if (statusEnum == LabResultStatus.high) flagColor = AppColors.error;
                      if (statusEnum == LabResultStatus.low) flagColor = Colors.blue;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: flagColor.withValues(alpha: 0.15),
                          child: Icon(Icons.biotech_rounded, color: flagColor, size: 20),
                        ),
                        title: Text(
                          lab['test_name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          'تاريخ الفحص: ${lab['test_date']} | النتيجة: ${lab['measured_value']} ${lab['unit']} | المدى الطبيعي: ${lab['reference_range']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: flagColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: flagColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            statusEnum.displayName,
                            style: TextStyle(color: flagColor, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
