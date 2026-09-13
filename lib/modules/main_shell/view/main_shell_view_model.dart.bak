import 'package:flutter/material.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/security/session_manager.dart';

class NavigationMenuItem {
  final String key;
  final String title;
  final IconData icon;

  const NavigationMenuItem({
    required this.key,
    required this.title,
    required this.icon,
  });
}

class MainShellViewModel extends BaseViewModel {
  MainShellViewModel(super.reLoad);

  int selectedIndex = 0;

  static const List<NavigationMenuItem> allMenuItems = [
    NavigationMenuItem(key: 'dashboard', title: 'لوحة التحكم', icon: Icons.dashboard_rounded),
    NavigationMenuItem(key: 'appointments', title: 'جدول المواعيد والحجوزات', icon: Icons.calendar_month_rounded),
    NavigationMenuItem(key: 'waiting_room', title: 'شاشة الانتظار والاستقبال', icon: Icons.people_alt_rounded),
    NavigationMenuItem(key: 'emr', title: 'الملف الطبي للمرضى', icon: Icons.folder_shared_rounded),
    NavigationMenuItem(key: 'consultation', title: 'الكشف والروشتة الإلكترونية', icon: Icons.medical_services_rounded),
    NavigationMenuItem(key: 'billing', title: 'الحسابات والفواتير', icon: Icons.receipt_long_rounded),
    NavigationMenuItem(key: 'inventory', title: 'مخزن المستلزمات الطبية', icon: Icons.inventory_2_rounded),
    NavigationMenuItem(key: 'reports', title: 'التقارير والإحصائيات', icon: Icons.analytics_rounded),
    NavigationMenuItem(key: 'settings', title: 'الإعدادات وإدارة المستخدمين', icon: Icons.settings_rounded),
  ];

  List<NavigationMenuItem> get allowedMenuItems {
    return allMenuItems.where((item) {
      return SessionManager.instance.hasPermission(item.key);
    }).toList();
  }

  void selectTab(int index) {
    if (index >= 0 && index < allowedMenuItems.length) {
      selectedIndex = index;
      notifyListeners();
    }
  }
}
