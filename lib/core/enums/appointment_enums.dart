enum AppointmentStatus {
  waiting('waiting', 'في الانتظار'),
  inProgress('in_progress', 'جاري الكشف'),
  completed('completed', 'مكتمل'),
  cancelled('cancelled', 'ملغى'),
  noShow('no_show', 'لم يحضر');

  final String dbValue;
  final String displayName;

  const AppointmentStatus(this.dbValue, this.displayName);

  static AppointmentStatus fromString(String? statusStr) {
    if (statusStr == null || statusStr.isEmpty) return AppointmentStatus.waiting;
    final s = statusStr.trim().toLowerCase();
    if (s == 'in_progress' || s == 'in_consultation' || s == 'جاري الكشف' || s == 'في الكشف') return AppointmentStatus.inProgress;
    if (s == 'completed' || s == 'مكتمل') return AppointmentStatus.completed;
    if (s == 'cancelled' || s == 'canceled' || s == 'ملغى') return AppointmentStatus.cancelled;
    if (s == 'no_show' || s == 'لم يحضر') return AppointmentStatus.noShow;
    return AppointmentStatus.waiting;
  }

  bool get isWaiting => this == AppointmentStatus.waiting;
  bool get isInProgress => this == AppointmentStatus.inProgress;
  bool get isCompleted => this == AppointmentStatus.completed;
  bool get isCancelled => this == AppointmentStatus.cancelled;
}

enum AppointmentType {
  newConsultation('new_consultation', 'كشف جديد'),
  followUp('follow_up', 'إعادة / استشارة'),
  labReview('lab_review', 'متابعة نتائج');

  final String dbValue;
  final String displayName;

  const AppointmentType(this.dbValue, this.displayName);

  static AppointmentType fromString(String? typeStr) {
    if (typeStr == null || typeStr.isEmpty) return AppointmentType.newConsultation;
    final t = typeStr.trim().toLowerCase();
    if (t == 'follow_up' || t == 'إعادة / استشارة' || t == 'استشارة') return AppointmentType.followUp;
    if (t == 'lab_review' || t == 'متابعة نتيجه تحاليل' || t == 'متابعة نتائج') return AppointmentType.labReview;
    return AppointmentType.newConsultation;
  }
}

enum AppointmentPriority {
  normal('normal', 'عادي'),
  urgent('urgent', 'مستعجل'),
  emergency('emergency', 'حالة طارئة');

  final String dbValue;
  final String displayName;

  const AppointmentPriority(this.dbValue, this.displayName);

  static AppointmentPriority fromString(String? priorityStr) {
    if (priorityStr == null || priorityStr.isEmpty) return AppointmentPriority.normal;
    final p = priorityStr.trim().toLowerCase();
    if (p == 'urgent' || p == 'مستعجل' || p == 'عاجل') return AppointmentPriority.urgent;
    if (p == 'emergency' || p == 'stat' || p == 'حالة طارئة' || p == 'طارئ') return AppointmentPriority.emergency;
    return AppointmentPriority.normal;
  }

  bool get isNormal => this == AppointmentPriority.normal;
  bool get isUrgent => this == AppointmentPriority.urgent;
  bool get isEmergency => this == AppointmentPriority.emergency;
}

enum PatientGender {
  male('male', 'ذكر'),
  female('female', 'أنثى');

  final String dbValue;
  final String displayName;

  const PatientGender(this.dbValue, this.displayName);

  static PatientGender fromString(String? genderStr) {
    if (genderStr == null || genderStr.isEmpty) return PatientGender.male;
    final g = genderStr.trim().toLowerCase();
    if (g == 'female' || g == 'أنثى') return PatientGender.female;
    return PatientGender.male;
  }
}
