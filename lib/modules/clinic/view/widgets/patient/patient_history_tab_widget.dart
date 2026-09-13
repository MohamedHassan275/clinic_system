import 'package:flutter/material.dart';
import '../../../../../core/enums/appointment_enums.dart';
import '../../../../../core/theme/app_colors.dart';

class PatientHistoryTabWidget extends StatelessWidget {
  final Map<String, dynamic>? selectedPatientRecord;
  final Map<String, dynamic> patient;

  const PatientHistoryTabWidget({
    super.key,
    required this.selectedPatientRecord,
    required this.patient,
  });

  @override
  Widget build(BuildContext context) {
    final appointments = selectedPatientRecord != null ? (selectedPatientRecord!['appointments'] as List? ?? []) : [];
    final prescriptions = selectedPatientRecord != null ? (selectedPatientRecord!['prescriptions'] as List? ?? []) : [];

    // Combine timeline events
    final List<Map<String, dynamic>> timelineEvents = [];

    for (var appt in appointments) {
      final apptStatus = AppointmentStatus.fromString(appt['status'] as String?);
      final apptType = AppointmentType.fromString(appt['type'] as String?);

      timelineEvents.add({
        'category': 'appointment',
        'title': 'زيارة عيادة: ${apptType.displayName}',
        'date': appt['appointment_date'] ?? appt['created_at'] ?? '',
        'time': appt['time_slot'] ?? '',
        'doctor': appt['doctor_name'] ?? 'دكتور العيادة',
        'status': apptStatus.displayName,
        'status_enum': apptStatus,
        'notes': appt['notes'] ?? '',
      });
    }

    for (var rx in prescriptions) {
      timelineEvents.add({
        'category': 'prescription',
        'title': 'صدور روشتة إلكترونية',
        'date': rx['created_at'] ?? '',
        'time': '',
        'doctor': rx['doctor_name'] ?? 'دكتور العيادة',
        'status': 'مكتمل',
        'notes': 'التشخيص: ${rx['diagnosis'] ?? 'غير محدد'}',
      });
    }

    // Sort timeline descending by date
    timelineEvents.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('السجل المرضي والكشوفات السابقة (Clinical Timeline)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Text('التسلسل الزمني للزيارات، التشخيصات السريرية، وملاحظات الأطباء', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Expanded(
            child: timelineEvents.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off_rounded, size: 48, color: AppColors.textLight),
                        SizedBox(height: 12),
                        Text('لا يوجد سجل زيارات أو كشوفات تاريخية سابقة لهذا المريض', style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: timelineEvents.length,
                    itemBuilder: (context, index) {
                      final item = timelineEvents[index];
                      final bool isRx = item['category'] == 'prescription';

                      Color badgeColor = AppColors.primary;
                      if (isRx) badgeColor = AppColors.secondary;
                      if (item['status_enum'] != null) {
                        final AppointmentStatus st = item['status_enum'];
                        if (st.isCompleted) badgeColor = AppColors.success;
                        if (st.isCancelled) badgeColor = AppColors.error;
                        if (st.isWaiting) badgeColor = Colors.amber;
                      }

                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Timeline Pillar Line & Icon
                            SizedBox(
                              width: 40,
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: badgeColor.withValues(alpha: 0.2),
                                    child: Icon(
                                      isRx ? Icons.receipt_long_rounded : Icons.local_hospital_rounded,
                                      size: 14,
                                      color: badgeColor,
                                    ),
                                  ),
                                  if (index != timelineEvents.length - 1)
                                    Expanded(
                                      child: Container(
                                        width: 2,
                                        color: AppColors.border,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Timeline Content Card
                            Expanded(
                              child: Card(
                                elevation: 1,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: badgeColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              item['status'] ?? '',
                                              style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'التاريخ: ${item['date']} ${item['time'].toString().isNotEmpty ? '(${item['time']})' : ''} | المعالج: د. ${item['doctor']}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                      if (item['notes'] != null && (item['notes'] as String).isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(item['notes'], style: const TextStyle(fontSize: 12)),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
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
