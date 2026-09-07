import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/security/session_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../shared/cubit/base_cubit.dart';
import '../../auth/view/login_screen.dart';
import '../../clinic/data/cubit/clinic_cubit.dart';
import '../../clinic/view/screens/appointments_screen.dart';
import '../../clinic/view/screens/billing_screen.dart';
import '../../clinic/view/screens/consultation_screen.dart';
import '../../clinic/view/screens/dashboard_screen.dart';
import '../../clinic/view/screens/emr_screen.dart';
import '../../clinic/view/screens/inventory_screen.dart';
import '../../clinic/view/screens/reports_screen.dart';
import '../../clinic/view/screens/settings_screen.dart';
import '../../clinic/view/screens/waiting_room_screen.dart';
import 'main_shell_view_model.dart';

class ClinicMainShell extends StatefulWidget {
  const ClinicMainShell({super.key});

  @override
  State<ClinicMainShell> createState() => _ClinicMainShellState();
}

class _ClinicMainShellState extends State<ClinicMainShell> {
  late final MainShellViewModel _viewModel;
  late final ClinicCubit _clinicCubit;

  @override
  void initState() {
    super.initState();
    _clinicCubit = sl<ClinicCubit>();
    _viewModel = sl<MainShellViewModel>()..updateRefresh(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clinicCubit.close();
    _viewModel.dispose();
    super.dispose();
  }

  Widget _getScreenWidget(String key) {
    return KeyedSubtree(
      key: ValueKey(key),
      child: () {
        switch (key) {
          case 'dashboard':
            return const DashboardScreen();
          case 'appointments':
            return const AppointmentsScreen();
          case 'waiting_room':
            return const WaitingRoomScreen();
          case 'emr':
            return const EMRScreen();
          case 'consultation':
            return const ConsultationScreen();
          case 'billing':
            return const BillingScreen();
          case 'inventory':
            return const InventoryScreen();
          case 'reports':
            return const ReportsScreen();
          case 'settings':
            return const SettingsScreen();
          default:
            return const DashboardScreen();
        }
      }(),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: AppColors.error),
            SizedBox(width: 8),
            Text('تأكيد تسجيل الخروج'),
          ],
        ),
        content: const Text('هل أنت تأكد من رغبتك في تسجيل الخروج من نظام العيادة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.of(ctx).pop();
              SessionManager.instance.clearSession();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _clinicCubit,
      child: BlocBuilder<ClinicCubit, BaseState<ClinicApiType>>(
        builder: (context, state) {
          final allowedItems = _viewModel.allowedMenuItems;
          final int validIndex = _viewModel.selectedIndex.clamp(0, allowedItems.isEmpty ? 0 : allowedItems.length - 1);
          final currentKey = allowedItems.isNotEmpty ? allowedItems[validIndex].key : 'dashboard';

          return Directionality(
            textDirection: TextDirection.rtl,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isDesktop = constraints.maxWidth >= 1024;

                if (isDesktop) {
                  return Scaffold(
                    body: Row(
                      children: [
                        // Persistent Fixed Right Sidebar (260px)
                        SizedBox(
                          width: 260,
                          child: _buildSidebarContent(allowedItems, validIndex, isDesktop: true),
                        ),
                        const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
                        // Left Dynamic View Container
                        Expanded(
                          child: _getScreenWidget(currentKey),
                        ),
                      ],
                    ),
                  );
                } else {
                  // Mobile Layout (< 1024px)
                  return Scaffold(
                    appBar: AppBar(
                      title: Text(allowedItems.isNotEmpty ? allowedItems[validIndex].title : 'نظام العيادات'),
                      centerTitle: false,
                    ),
                    endDrawer: Drawer(
                      child: _buildSidebarContent(allowedItems, validIndex, isDesktop: false),
                    ),
                    body: _getScreenWidget(currentKey),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSidebarContent(List<NavigationMenuItem> items, int selectedIndex, {required bool isDesktop}) {
    final user = SessionManager.instance.currentUser;
    final String fullName = user != null ? user['full_name'] : 'مستخدم العيادة';
    final String role = user != null ? (user['role'] == 'admin' ? 'طبيب / مدير النظام' : 'موظف استقبال') : '';

    return Container(
      color: AppColors.sidebarBackground,
      child: Column(
        children: [
          // Header Logo & Active User Profile
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_hospital, color: AppColors.accent, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'عيادتي الذكية',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            'نظام الإدارة الشامل',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primary,
                        child: Icon(Icons.person, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              role,
                              style: const TextStyle(color: AppColors.accent, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Dynamic Menu List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final bool isSelected = selectedIndex == index;
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    selected: isSelected,
                    selectedTileColor: AppColors.sidebarSelected,
                    leading: Icon(
                      item.icon,
                      color: isSelected ? Colors.white : Colors.white60,
                      size: 22,
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () {
                      _viewModel.selectTab(index);
                      if (mounted) setState(() {});
                      if (!isDesktop) {
                        Navigator.of(context).pop(); // Close drawer on mobile
                      }
                    },
                  ),
                );
              },
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Bottom Logout Action
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              tileColor: Colors.red.withOpacity(0.12),
              leading: const Icon(Icons.logout, color: Colors.redAccent, size: 22),
              title: const Text(
                'تسجيل الخروج',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onTap: () {
                if (!isDesktop) Navigator.of(context).pop();
                _confirmLogout();
              },
            ),
          ),
        ],
      ),
    );
  }
}

