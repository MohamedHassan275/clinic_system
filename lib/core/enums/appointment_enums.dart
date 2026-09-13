enum AppointmentStatus {
  waiting,
  inProgress,
  completed,
  cancelled,
  noShow;

  static AppointmentStatus fromString(String? statusStr) {
    if (statusStr == null || statusStr.isEmpty) return AppointmentStatus.waiting;
    final s = statusStr.trim().toLowerCase();
    if (s == 'in_progress' || s == 'in_consultation' || s == 'جاري الكشف') return AppointmentStatus.inProgress;
    if (s == 'completed' || s == 'مكتمل') return AppointmentStatus.completed;
    if (s == 'cancelled' || s == 'canceled' || s == 'ملغى') return AppointmentStatus.cancelled;
    if (s == 'no_show' || s == 'لم يحضر') return AppointmentStatus.noShow;
    return AppointmentStatus.waiting;
  }

  /// English code stored in Database
  String get dbValue {
    switch (this) {
      case AppointmentStatus.waiting:
        return 'waiting';
      case AppointmentStatus.inProgress:
        return 'in_progress';
      case AppointmentStatus.completed:
        return 'completed';
      case AppointmentStatus.cancelled:
        return 'cancelled';
      case AppointmentStatus.noShow:
        return 'no_show';
    }
  }

  /// Arabic text displayed in UI
  String get displayName {
    switch (this) {
      case AppointmentStatus.waiting:
        return 'في الانتظار';
      case AppointmentStatus.inProgress:
        return 'جاري الكشف';
      case AppointmentStatus.completed:
        return 'مكتمل';
      case AppointmentStatus.cancelled:
        return 'ملغى';
      case AppointmentStatus.noShow:
        return 'لم يحضر';
    }
  }

  bool get isWaiting => this == AppointmentStatus.waiting;
  bool get isInProgress => this == AppointmentStatus.inProgress;
  bool get isCompleted => this == AppointmentStatus.completed;
  bool get isCancelled => this == AppointmentStatus.cancelled;
}

enum AppointmentType {
  newConsultation,
  followUp,
  labReview;

  static AppointmentType fromString(String? typeStr) {
    if (typeStr == null || typeStr.isEmpty) return AppointmentType.newConsultation;
    final t = typeStr.trim().toLowerCase();
    if (t == 'follow_up' || t == 'إعادة / استشارة' || t == 'استشارة') return AppointmentType.followUp;
    if (t == 'lab_review' || t == 'متابعة نتيجه تحاليل' || t == 'متابعة نتائج') return AppointmentType.labReview;
    return AppointmentType.newConsultation;
  }

  /// English code stored in Database
  String get dbValue {
    switch (this) {
      case AppointmentType.newConsultation:
        return 'new_consultation';
      case AppointmentType.followUp:
        return 'follow_up';
      case AppointmentType.labReview:
        return 'lab_review';
    }
  }

  /// Arabic text displayed in UI
  String get displayName {
    switch (this) {
      case AppointmentType.newConsultation:
        return 'كشف جديد';
      case AppointmentType.followUp:
        return 'إعادة / استشارة';
      case AppointmentType.labReview:
        return 'متابعة نتائج';
    }
  }
}

enum PatientGender {
  male,
  female;

  static PatientGender fromString(String? genderStr) {
    if (genderStr == null || genderStr.isEmpty) return PatientGender.male;
    final g = genderStr.trim().toLowerCase();
    if (g == 'female' || g == 'أنثى') return PatientGender.female;
    return PatientGender.male;
  }

  String get dbValue => this == PatientGender.female ? 'female' : 'male';
  String get displayName => this == PatientGender.female ? 'أنثى' : 'ذكر';
}
