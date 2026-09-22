import 'package:flutter/material.dart';
import '../../../../../core/enums/appointment_enums.dart';
import '../../../../../core/enums/payment_enums.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/date_formatter.dart';

class PatientProfileTabWidget extends StatelessWidget {
  final Map<String, dynamic> patient;
  final VoidCallback? onEditPressed;

  const PatientProfileTabWidget({
    super.key,
    required this.patient,
    this.onEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    final String name = patient['name'] ?? 'مريض بدون اسم';
    final String phone = patient['phone'] ?? 'غير مسجل';
    final String nationalId = patient['national_id'] ?? 'غير مسجل';
    final int age = (patient['age'] as num?)?.toInt() ?? 0;
    final String dob = DateFormatter.formatDate(patient['dob'], fallback: 'غير مسجل');

    final String genderRaw = patient['gender'] ?? 'male';
    final PatientGender gender = PatientGender.fromString(genderRaw);

    final String bloodGroup = patient['blood_group'] ?? 'غير محدد';
    final String femaleStatus = patient['female_status'] ?? 'طبيعي';
    final String emergencyPhone = patient['emergency_phone'] ?? 'غير مسجل';

    final String contractEntityRaw = patient['contract_entity'] ?? 'cash';
    final PaymentMethod contractEntity = PaymentMethod.fromString(contractEntityRaw);

    final String allergies = (patient['allergies'] == null || patient['allergies'].toString().trim().isEmpty)
        ? 'لا توجد حساسيات مسجلة'
        : patient['allergies'];

    final String chronicDiseases = (patient['chronic_diseases'] == null || patient['chronic_diseases'].toString().trim().isEmpty)
        ? 'لا توجد أمراض مزمنة مسجلة'
        : patient['chronic_diseases'];

    final String medicalHistory = (patient['medical_history'] == null || patient['medical_history'].toString().trim().isEmpty)
        ? 'لا توجد ملاحظات سريرية سابقة.'
        : patient['medical_history'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card with Primary Action
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      name.isNotEmpty ? name[0] : 'P',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#${patient['id'] ?? ''}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'الهاتف: $phone | الرقم القومي: $nationalId',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (onEditPressed != null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: onEditPressed,
                      icon: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 18),
                      label: const Text('تعديل البيانات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 1: Demographics & Clinical Profile
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildInfoGroupCard(
                  title: '1. البيانات الشخصية والديموغرافية',
                  icon: Icons.person_outline_rounded,
                  items: [
                    _InfoItem('السن الحالي', '$age سنة'),
                    _InfoItem('تاريخ الميلاد', dob),
                    _InfoItem('النوع / الجنس', gender.displayName),
                    _InfoItem('فصيلة الدم', bloodGroup),
                    if (gender == PatientGender.female)
                      _InfoItem('الحالة الفسيولوجية', femaleStatus),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildInfoGroupCard(
                  title: '2. التعاقد وهاتف الطوارئ',
                  icon: Icons.contact_phone_outlined,
                  items: [
                    _InfoItem('جهة التعاقد / الفئة', contractEntity.displayName),
                    _InfoItem('هاتف الطوارئ / القرابة', emergencyPhone),
                    _InfoItem('تاريخ التسجيل بالعيادة', DateFormatter.formatDate(patient['created_at'], fallback: 'غير محدد')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 2: High-Risk Alert Card (Allergies & Chronic Diseases)
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            color: Colors.amber.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'التنبيهات السريرية والحالات الحرجة',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.amber),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('الحساسيات المفرطة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(10),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                allergies,
                                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('الأمراض المزمنة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(10),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                chronicDiseases,
                                style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 3: General Medical History Notes
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.notes_rounded, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text('السجل الطبي والملاحظات العامة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      medicalHistory,
                      style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGroupCard({
    required String title,
    required IconData icon,
    required List<_InfoItem> items,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),
            ...items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    Text(item.value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _InfoItem {
  final String label;
  final String value;
  const _InfoItem(this.label, this.value);
}
