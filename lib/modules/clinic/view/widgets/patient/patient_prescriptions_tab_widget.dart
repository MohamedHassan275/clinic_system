import 'package:flutter/material.dart';
import '../../../../../core/common/widgets/app_dialog.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/date_formatter.dart';

class PatientPrescriptionsTabWidget extends StatelessWidget {
  final Map<String, dynamic>? selectedPatientRecord;
  final Map<String, dynamic> patient;

  const PatientPrescriptionsTabWidget({
    super.key,
    required this.selectedPatientRecord,
    required this.patient,
  });

  void _showPrescriptionDetailsModal(BuildContext context, Map<String, dynamic> rx) {
    final List items = rx['items'] as List? ?? [];
    final String doctorName = rx['doctor_name'] ?? 'دكتور العيادة';
    final String diagnosis = rx['diagnosis'] ?? 'غير محدد';
    final String date = rx['created_at'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'تفاصيل الروشتة الإلكترونية',
        subtitle: 'تاريخ الصدور: ${DateFormatter.formatDate(date)} | الطبيب المعالج: د. $doctorName',
        icon: Icons.receipt_long_rounded,
        iconColor: AppColors.primary,
        maxWidth: 550,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.medical_information_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'التشخيص الطبي: $diagnosis',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text('الأدويـة والجرعـات المقررة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text('لا توجد عناصر أدوية مسجلة في هذه الروشتة.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
            else
              ...items.map((item) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: ListTile(
                    dense: true,
                    leading: const CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.secondary,
                      child: Icon(Icons.medication_rounded, size: 14, color: Colors.white),
                    ),
                    title: Text(
                      item['medicine_name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: Text(
                      'الجرعة: ${item['dosage'] ?? ''} | التكرار: ${item['frequency'] ?? ''} | المدة: ${item['duration'] ?? ''}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                );
              }),
            if (rx['notes'] != null && (rx['notes'] as String).isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('تعليمات وإرشادات الطبيب: ${rx['notes']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
            ],
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('جاري فتح طباعة الروشتة...'), backgroundColor: AppColors.primary),
              );
            },
            icon: const Icon(Icons.print_rounded, color: Colors.white, size: 18),
            label: const Text('طباعة / معاينة الروشتة', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rxList = selectedPatientRecord != null ? (selectedPatientRecord!['prescriptions'] as List? ?? []) : [];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('سجل الروشتات الإلكترونية الصادرة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Text('عرض الأدوية، التشخيصات السابقة، وطباعة الروشتات الرسمية', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Expanded(
            child: rxList.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textLight),
                        SizedBox(height: 12),
                        Text('لا توجد روشتات سابقة صادرة لهذا المريض', style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: rxList.length,
                    itemBuilder: (context, index) {
                      final rx = rxList[index];
                      final List items = rx['items'] as List? ?? [];
                      final String date = rx['created_at'] ?? '';
                      final String diagnosis = rx['diagnosis'] ?? 'غير محدد';
                      final String doctorName = rx['doctor_name'] ?? 'دكتور العيادة';

                      return Card(
                        elevation: 1.5,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.receipt_rounded, color: AppColors.primary, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'روشتة بتاريخ: ${DateFormatter.formatDate(date)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'طبيب: د. $doctorName',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              Row(
                                children: [
                                  const Text('التشخيص: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Expanded(
                                    child: Text(
                                      diagnosis,
                                      style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'عدد الأدوية المسجلة: ${items.length} اصناف دارجة بالروشتة',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _showPrescriptionDetailsModal(context, rx),
                                    icon: const Icon(Icons.visibility_rounded, size: 16),
                                    label: const Text('عرض التفاصيل والطباعة', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
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
