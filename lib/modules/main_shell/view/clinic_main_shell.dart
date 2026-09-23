import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/enums/user_role.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/security/session_manager.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/sync/widgets/migration_progress_dialog.dart';
import '../../../../core/sync/widgets/sync_status_indicator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../auth/view/login_screen.dart';
import '../../clinic/data/cubit/clinic_cubit.dart';
import '../../clinic/view/screens/appointments_screen.dart';
import '../../clinic/view/screens/billing_screen.dart';
import '../../clinic/view/screens/consultation_screen.dart';
import '../../clinic/view/screens/dashboard_screen.dart';
import '../../clinic/view/screens/doctor_dashboard_screen.dart';
import '../../clinic/view/screens/emr_screen.dart';
import '../../clinic/view/screens/inventory_screen.dart';
import '../../clinic/view/screens/reception_screen.dart';
import '../../clinic/view/screens/reports_screen.dart';
import '../../clinic/view/screens/settings_screen.dart';
import '../../clinic/view/screens/waiting_room_screen.dart';
import '../../shared/cubit/base_cubit.dart';
import 'main_shell_view_model.dart';

class ClinicMainShell extends StatefulWidget {
  const ClinicMainShell({super.key});

  @override
  State<ClinicMainShell> createState() => _ClinicMainShellState();
}

class _ClinicMainShellState extends State<ClinicMainShell> {
  late final MainShellViewModel _viewModel;
  late final ClinicCubit _clinicCubit;
  bool _migrationDialogShown = false;

  @override
  void initState() {
    super.initState();
    _clinicCubit = sl<ClinicCubit>();
    _viewModel = sl<MainShellViewModel>()..updateRefresh(() {
      if (mounted) setState(() {});
    });

    SyncService.instance.migrationProgressNotifier.addListener(_handleMigrationProgressChange);
  }

  @override
  void dispose() {
    SyncService.instance.migrationProgressNotifier.removeListener(_handleMigrationProgressChange);
    _clinicCubit.close();
    _viewModel.dispose();
    super.dispose();
  }

  void _handleMigrationProgressChange() {
    if (!mounted) return;
    final progress = SyncService.instance.migrationProgressNotifier.value;

    if (progress.isMigrating && !_migrationDialogShown) {
      _migrationDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const MigrationProgressDialog(),
        ).then((_) {
          _migrationDialogShown = false;
        });
      });
    } else if (!progress.isMigrating && progress.isCompleted && _migrationDialogShown) {
      _migrationDialogShown = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      });
    }
  }

  void _switchPortal(UserRole mode) {
    _viewModel.toggleAdminRoleView(mode);
    if (mounted) setState(() {});
  }

  Widget _getScreenWidget(String key) {
    final role = _viewModel.activeRoleMode;
    return KeyedSubtree(
      key: ValueKey('${role.dbValue}_$key'),
      child: () {
        switch (key) {
          case 'dashboard':
          case 'doctor_dashboard':
            return role == UserRole.doctor
                ? const DoctorDashboardScreen()
                : const DashboardScreen();
          case 'reception':
            return const ReceptionScreen();
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
            return role == UserRole.doctor
                ? const DoctorDashboardScreen()
                : const DashboardScreen();
        }
      }(),
    );
  }

  Future<void> _showExitAppDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app, color: AppColors.primary),
            SizedBox(width: 8),
            Text('الخروج من التطبيق'),
          ],
        ),
        content: const Text('هل تريد الخروج من التطبيق بالكامل؟ (سيظل حسابك متصلاً عند العودة)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.of(ctx).pop();
              SystemNavigator.pop();
            },
            child: const Text('خروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
            Text('تسجيل الخروج من التطبيق'),
          ],
        ),
        content: const Text('هل أنت تأكد من رغبتك في تسجيل الخروج وإلغاء الوردية الحالية والجلسة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final activeShift = SessionManager.instance.activeShift;
              if (activeShift != null && activeShift['id'] != null) {
                try {
                  final db = await DatabaseHelper.instance.database;
                  final nowStr = DateTime.now().toIso8601String();
                  await db.update(
                    'shifts',
                    {'end_time': nowStr, 'is_closed': 1},
                    where: 'id = ?',
                    whereArgs: [activeShift['id']],
                  );
                } catch (_) {}
              }
              SessionManager.instance.setActiveShift(null);
              await SessionManager.instance.clearSession();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
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
          final int validIndex = _viewModel.selectedIndex.clamp(
            0,
            allowedItems.isEmpty ? 0 : allowedItems.length - 1,
          );
          final currentKey = allowedItems.isNotEmpty
              ? allowedItems[validIndex].key
              : 'dashboard';

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              await _showExitAppDialog();
            },
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: ResponsiveLayout(
                // Mobile Layout (< 600px)
                mobile: Scaffold(
                  appBar: AppBar(
                    title: Text(
                      allowedItems.isNotEmpty ? allowedItems[validIndex].title : 'نظام العيادات',
                    ),
                    centerTitle: false,
                    actions: const [
                      SyncStatusIndicator(),
                      SizedBox(width: 8),
                    ],
                  ),
                  endDrawer: Drawer(
                    child: _buildSidebarContent(allowedItems, validIndex, isDesktop: false),
                  ),
                  body: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _getScreenWidget(currentKey),
                  ),
                ),

                // Tablet Layout (600px - 1023px)
                tablet: Scaffold(
                  body: Row(
                    children: [
                      SizedBox(
                        width: 220,
                        child: _buildSidebarContent(allowedItems, validIndex, isDesktop: true, isCompact: true),
                      ),
                      const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _getScreenWidget(currentKey),
                        ),
                      ),
                    ],
                  ),
                ),

                // Desktop Layout (>= 1024px)
                desktop: Scaffold(
                  body: Row(
                    children: [
                      SizedBox(
                        width: 270,
                        child: _buildSidebarContent(allowedItems, validIndex, isDesktop: true),
                      ),
                      const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _getScreenWidget(currentKey),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSidebarContent(
    List<NavigationMenuItem> items,
    int selectedIndex, {
    required bool isDesktop,
    bool isCompact = false,
  }) {
    final user = SessionManager.instance.currentUser;
    final String fullName = user != null ? (user['full_name'] ?? 'مستخدم العيادة') : 'مستخدم العيادة';
    final UserRole role = _viewModel.currentRole;

    return Container(
      color: AppColors.sidebarBackground,
      child: Column(
        children: [
          // Header Logo & Active User Profile
          Padding(
            padding: EdgeInsets.all(isCompact ? 12.0 : 16.0),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_hospital, color: AppColors.accent, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'عيادتي الذكية',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: isCompact ? 16 : 18,
                            ),
                          ),
                          const Text(
                            'نظام الإدارة الشامل',
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SyncStatusIndicator(),
                  ],
                ),
                const SizedBox(height: 16),
                // User Profile Box
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: role == UserRole.doctor
                            ? AppColors.primary
                            : (role == UserRole.superAdmin ? Colors.purple : AppColors.secondary),
                        child: Icon(
                          role == UserRole.doctor ? Icons.medical_services : Icons.person,
                          color: Colors.white,
                          size: 18,
                        ),
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              role.displayName,
                              style: const TextStyle(color: AppColors.accent, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // SuperAdmin Role Switcher Toggle
                if (role == UserRole.superAdmin) ...[
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _switchPortal(UserRole.doctor),
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: _viewModel.activeRoleMode == UserRole.doctor
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'الطبيب',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => _switchPortal(UserRole.secretary),
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: _viewModel.activeRoleMode == UserRole.secretary
                                    ? AppColors.secondary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'الاستقبال',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Dynamic Menu List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
                      size: 20,
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: isCompact ? 12 : 13,
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
            padding: const EdgeInsets.all(10.0),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              tileColor: Colors.red.withValues(alpha: 0.12),
              leading: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
              title: const Text(
                'تسجيل الخروج',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
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
