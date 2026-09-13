import 'package:flutter/material.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/enums/user_role.dart';
import '../../../../core/security/session_manager.dart';

class NavigationMenuItem {
  final String key;
  final String title;
  final IconData icon;
  final UserRole targetRole;

  const NavigationMenuItem({
    required this.key,
    required this.title,
    required this.icon,
    required this.targetRole,
  });
}

class MainShellViewModel extends BaseViewModel {
  MainShellViewModel(super.reLoad);

  int selectedIndex = 0;
  UserRole? _activeAdminViewRole; // For SuperAdmin switching mode

  UserRole get currentRole {
    final user = SessionManager.instance.currentUser;
    return UserRole.fromString(user?['role']);
  }

  /// Active role mode (for SuperAdmin toggle support)
  UserRole get activeRoleMode {
    final role = currentRole;
    if (role == UserRole.superAdmin) {
      return _activeAdminViewRole ?? UserRole.doctor;
    }
    return role;
  }

  void toggleAdminRoleView(UserRole mode) {
    if (currentRole == UserRole.superAdmin) {
      _activeAdminViewRole = mode;
      selectedIndex = 0;
      notifyListeners();
    }
  }

  static const List<NavigationMenuItem> doctorMenuItems = [
    NavigationMenuItem(
      key: 'dashboard',
      title: 'لوحة التحكم الطبية',
      icon: Icons.dashboard_rounded,
      targetRole: UserRole.doctor,
    ),
    NavigationMenuItem(
      key: 'emr',
      title: 'الملف الطبي للمرضى',
      icon: Icons.folder_shared_rounded,
      targetRole: UserRole.doctor,
    ),
    NavigationMenuItem(
      key: 'consultation',
      title: 'الكشف والروشتة الإلكترونية',
      icon: Icons.medical_services_rounded,
      targetRole: UserRole.doctor,
    ),
    NavigationMenuItem(
      key: 'appointments',
      title: 'جدول المواعيد والكشوفات',
      icon: Icons.calendar_month_rounded,
      targetRole: UserRole.doctor,
    ),
    NavigationMenuItem(
      key: 'reports',
      title: 'التقارير والإحصائيات',
      icon: Icons.analytics_rounded,
      targetRole: UserRole.doctor,
    ),
  ];

  static const List<NavigationMenuItem> secretaryMenuItems = [
    NavigationMenuItem(
      key: 'reception',
      title: 'منصة مكتب الاستقبال',
      icon: Icons.desk_rounded,
      targetRole: UserRole.secretary,
    ),
    NavigationMenuItem(
      key: 'waiting_room',
      title: 'شاشة الانتظار والاستقبال',
      icon: Icons.people_alt_rounded,
      targetRole: UserRole.secretary,
    ),
    NavigationMenuItem(
      key: 'appointments',
      title: 'حجز وتنسيق المواعيد',
      icon: Icons.calendar_month_rounded,
      targetRole: UserRole.secretary,
    ),
    NavigationMenuItem(
      key: 'billing',
      title: 'الحسابات والفواتير والتحصيل',
      icon: Icons.receipt_long_rounded,
      targetRole: UserRole.secretary,
    ),
    NavigationMenuItem(
      key: 'emr',
      title: 'البحث وملفات المرضى',
      icon: Icons.folder_shared_rounded,
      targetRole: UserRole.secretary,
    ),
  ];

  static const NavigationMenuItem settingsItem = NavigationMenuItem(
    key: 'settings',
    title: 'إعدادات النظام والمستخدمين',
    icon: Icons.settings_rounded,
    targetRole: UserRole.superAdmin,
  );

  List<NavigationMenuItem> get allowedMenuItems {
    final role = activeRoleMode;
    final List<NavigationMenuItem> baseItems;

    if (role == UserRole.doctor) {
      baseItems = List.from(doctorMenuItems);
    } else {
      baseItems = List.from(secretaryMenuItems);
    }

    // Append settings if user is SuperAdmin
    if (currentRole == UserRole.superAdmin) {
      baseItems.add(settingsItem);
    }

    return baseItems;
  }

  void selectTab(int index) {
    if (index >= 0 && index < allowedMenuItems.length) {
      selectedIndex = index;
      notifyListeners();
    }
  }
}
