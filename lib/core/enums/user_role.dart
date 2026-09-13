enum UserRole {
  superAdmin('super_admin', 'مدير النظام (Super Admin)'),
  admin('admin', 'مدير الفرع (Admin)'),
  doctor('doctor', 'طبيب العيادة'),
  secretary('secretary', 'موظف الاستقبال'),
  nurse('nurse', 'ممرض');

  final String dbValue;
  final String displayName;

  const UserRole(this.dbValue, this.displayName);

  static UserRole fromString(String? roleStr) {
    if (roleStr == null || roleStr.isEmpty) return UserRole.secretary;
    final normalized = roleStr.trim().toLowerCase();
    if (normalized == 'super_admin' || normalized == 'superadmin' || normalized == 'سوبر أدمن') {
      return UserRole.superAdmin;
    }
    if (normalized == 'admin' || normalized == 'مدير') {
      return UserRole.admin;
    }
    if (normalized == 'doctor' || normalized == 'طبيب' || normalized == 'دكتور') return UserRole.doctor;
    if (normalized == 'secretary' || normalized == 'receptionist' || normalized == 'استقبال' || normalized == 'سكرتير') {
      return UserRole.secretary;
    }
    if (normalized == 'nurse' || normalized == 'ممرض') return UserRole.nurse;
    return UserRole.secretary;
  }

  bool get isDoctor => this == UserRole.doctor || this == UserRole.superAdmin;
  bool get isSecretary => this == UserRole.secretary || this == UserRole.superAdmin;
}
