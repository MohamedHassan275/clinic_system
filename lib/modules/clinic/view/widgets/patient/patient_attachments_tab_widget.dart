import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../core/common/widgets/app_dialog.dart';
import '../../../../../core/security/shift_guard.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../data/cubit/clinic_cubit.dart';

class PatientAttachmentsTabWidget extends StatelessWidget {
  final Map<String, dynamic>? selectedPatientRecord;
  final int patientId;
  final ClinicCubit cubit;

  const PatientAttachmentsTabWidget({
    super.key,
    required this.selectedPatientRecord,
    required this.patientId,
    required this.cubit,
  });

  void _showAddAttachmentDialog(BuildContext context) {
    if (!ShiftGuard.checkShiftOrWarn(context)) return;

    final fileNameCtrl = TextEditingController();
    String fileType = 'أشعة سينية / سيتي';
    final filePathCtrl = TextEditingController(text: '/storage/clinic/attachments/sample.pdf');

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AppDialog(
            title: 'إرفاق مستند خارجي أو صورة اشعة',
            subtitle: 'سجل المرفقات، الأشعة الخارجية والروشتات الورقية المصورة للمريض',
            icon: Icons.upload_file_rounded,
            iconColor: AppColors.secondary,
            maxWidth: 500,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: fileNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'عنوان المرفق / اسم الملف *',
                    hintText: 'مثال: أشعة سيتي على المخ، تقرير معمل خارجي',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: fileType,
                  decoration: const InputDecoration(labelText: 'نوع المرفق *'),
                  items: const [
                    DropdownMenuItem(value: 'أشعة سينية / سيتي', child: Text('أشعة سينية / X-Ray / CT')),
                    DropdownMenuItem(value: 'تقرير معملي خارجي', child: Text('تقرير معملي خارجي')),
                    DropdownMenuItem(value: 'روشتة ورقية مصورة', child: Text('روشتة ورقية مصورة')),
                    DropdownMenuItem(value: 'تقرير طب شرعي / عمليات', child: Text('تقرير طب شرعي / عمليات')),
                    DropdownMenuItem(value: 'مستند آخر', child: Text('مستند آخر')),
                  ],
                  onChanged: (val) => setModalState(() => fileType = val!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: filePathCtrl,
                  decoration: const InputDecoration(
                    labelText: 'مسار الملف أو الرابط (File Path / URI)',
                    prefixIcon: Icon(Icons.folder),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                onPressed: () async {
                  if (fileNameCtrl.text.trim().isEmpty) return;

                  final attachmentData = {
                    'patient_id': patientId,
                    'file_name': fileNameCtrl.text.trim(),
                    'file_type': fileType,
                    'file_path': filePathCtrl.text.trim(),
                    'created_at': DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                  };

                  await cubit.addPatientAttachment(attachmentData);
                  if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                },
                icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 18),
                label: const Text('حفظ المرفق', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attachList = selectedPatientRecord != null ? (selectedPatientRecord!['attachments'] as List? ?? []) : [];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('المرفقات والأشعّات والروشتات الخارجية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('إدارة المستندات المرفقة والتقارير الطبية الخارجية للمريض', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showAddAttachmentDialog(context),
                icon: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 18),
                label: const Text('إرفاق مستند جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Attachments List
          Expanded(
            child: attachList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.folder_open_outlined, size: 48, color: AppColors.textLight),
                        const SizedBox(height: 12),
                        const Text('لا توجد مرفقات خارجية مسجلة لهذا المريض حتى الآن', style: TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                          onPressed: () => _showAddAttachmentDialog(context),
                          icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
                          label: const Text('إرفاق أول مستند', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: attachList.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final at = attachList[index];
                      final String fileName = at['file_name'] ?? 'مستند';
                      final String fileType = at['file_type'] ?? 'عام';
                      final String date = at['created_at'] ?? '';

                      IconData iconData = Icons.insert_drive_file_rounded;
                      if (fileType.contains('أشعة')) iconData = Icons.photo_library_rounded;
                      if (fileType.contains('معمل')) iconData = Icons.science_rounded;
                      if (fileType.contains('روشتة')) iconData = Icons.description_rounded;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
                          child: Icon(iconData, color: AppColors.secondary, size: 20),
                        ),
                        title: Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('النوع: $fileType | تاريخ الإرفاق: $date', style: const TextStyle(fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.open_in_new_rounded, color: AppColors.primary, size: 20),
                          tooltip: 'فتح المستند',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('معاينة المستند: $fileName'), backgroundColor: AppColors.primary),
                            );
                          },
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
