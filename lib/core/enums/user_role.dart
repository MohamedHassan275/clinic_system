enum UserRole {
  doctor,
  secretary,
  superAdmin;

  static UserRole fromString(String? roleStr) {
    if (roleStr == null || roleStr.isEmpty) return UserRole.secretary;
    final normalized = roleStr.trim().toLowerCase();
    if (normalized == 'doctor' || normalized == 'طبيب') return UserRole.doctor;
    if (normalized == 'admin' ||
        normalized == 'super_admin' ||
        normalized == 'مدير' ||
        normalized == 'سوبر أدمن') {
      return UserRole.superAdmin;
    }
    return UserRole.secretary;
  }

  String get displayName {
    switch (this) {
      case UserRole.doctor:
        return 'طبيب العيادة';
      case UserRole.secretary:
        return 'موظف الاستقبال';
      case UserRole.superAdmin:
        return 'مدير النظام (Super Admin)';
    }
  }

  bool get isDoctor => this == UserRole.doctor || this == UserRole.superAdmin;
  bool get isSecretary => this == UserRole.secretary || this == UserRole.superAdmin;
}
