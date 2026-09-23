import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/common/widgets/app_dialog.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/security/session_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/view/screens/supabase_auth_test_screen.dart';
import '../../../shared/cubit/block_builder_widget.dart';
import '../../data/cubit/clinic_cubit.dart';
import '../clinic_view_model.dart';
import 'sync_status_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late final ClinicViewModel _viewModel;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _viewModel = sl<ClinicViewModel>()..updateRefresh(() {
      if (mounted) setState(() {});
    });
    _viewModel.clinicCubit.fetchUsers();
    _viewModel.clinicCubit.fetchClinicInfo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bool isMobile = media.size.width < 768;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 14.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الإعدادات وإدارة المستخدمين', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('التحكم في بيانات العيادة الأساسية وإدارة حسابات وصلاحيات الأطباء والموظفين', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
                Row(
                  children: [
                    // زر شاشة مراقبة المزامنة السحابية (Sync Status Screen)
                    IconButton(
                      icon: const Icon(Icons.cloud_sync_rounded, color: AppColors.primary),
                      tooltip: 'مراقبة حالة المزامنة السحابية',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SyncStatusScreen()),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    // زر اختبار الاتصال السحابي (Supabase Auth)
                    IconButton(
                      icon: const Icon(Icons.cloud_done_outlined, color: AppColors.secondary),
                      tooltip: 'اختبار الاتصال بالسحاب Supabase',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SupabaseAuthTestScreen()),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _showAddOrEditUserDialog(context),
                      icon: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 18),
                      label: const Text('إضافة حساب جديد +', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Bar
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(icon: Icon(Icons.people_outline), text: 'إدارة حسابات وصلاحيات الموظفين'),
                Tab(icon: Icon(Icons.storefront_outlined), text: 'بيانات وإعدادات العيادة'),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Users & Permissions
                  BlockBuilderWidget<ClinicCubit, ClinicApiType>(
                    types: const [ClinicApiType.getUsers],
                    body: (_) => _buildUsersList(),
                    loading: (_) => const Center(child: CircularProgressIndicator()),
                  ),
                  // Tab 2: Clinic General Info
                  BlockBuilderWidget<ClinicCubit, ClinicApiType>(
                    types: const [ClinicApiType.getClinicInfo],
                    body: (_) => _buildClinicSettingsForm(),
                    loading: (_) => const Center(child: CircularProgressIndicator()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersList() {
    final users = _viewModel.clinicCubit.usersList;
    if (users.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text('لا يوجد مستخدمون مسجلون في النظام')),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        itemCount: users.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final user = users[index];
          final String role = user['role'] ?? 'user';
          final bool isAdmin = role == 'admin' || role == 'super_admin';
          final String name = user['full_name'] ?? user['username'] ?? 'مستخدم';
          final String branch = user['branch'] ?? 'جميع الفروع';

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isAdmin ? Colors.purple.withValues(alpha: 0.15) : AppColors.primaryLight,
              child: Icon(
                isAdmin ? Icons.admin_panel_settings : Icons.person,
                color: isAdmin ? Colors.purple : AppColors.primary,
              ),
            ),
            title: Row(
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAdmin ? Colors.purple.withValues(alpha: 0.12) : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isAdmin ? 'Super Admin' : (role == 'doctor' ? 'طبيب' : 'استقبال'),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isAdmin ? Colors.purple : AppColors.primary),
                  ),
                ),
              ],
            ),
            subtitle: Text('اسم الدخول: ${user['username']} | الفرع: $branch'),
            trailing: IconButton(
              icon: const Icon(Icons.edit_note, color: AppColors.primary),
              onPressed: () => _showAddOrEditUserDialog(context, user: user),
            ),
          );
        },
      ),
    );
  }

  Widget _buildClinicSettingsForm() {
    final clinic = _viewModel.clinicCubit.clinicInfo;
    final nameCtrl = TextEditingController(text: clinic?['name'] ?? 'عيادتي الذكية');
    final phoneCtrl = TextEditingController(text: clinic?['phone'] ?? '01000000000');
    final addressCtrl = TextEditingController(text: clinic?['address'] ?? 'الفرع الرئيسي');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إعدادات وتفاصيل العيادة القانونية والطبية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم العيادة الرسمية', prefixIcon: Icon(Icons.local_hospital)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'هاتف التواصل الرئيسي', prefixIcon: Icon(Icons.phone)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'عنوان العيادة', prefixIcon: Icon(Icons.location_on)),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  await _viewModel.clinicCubit.updateClinicInfo({
                    'id': 1,
                    'name': nameCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'address': addressCtrl.text.trim(),
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم حفظ بيانات العيادة بنجاح!'), backgroundColor: AppColors.success),
                    );
                  }
                },
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text('حفظ البيانات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddOrEditUserDialog(BuildContext context, {Map<String, dynamic>? user}) {
    final bool isEdit = user != null;

    final fullNameCtrl = TextEditingController(text: isEdit ? (user['full_name'] ?? '') : '');
    final usernameCtrl = TextEditingController(text: isEdit ? (user['username'] ?? '') : '');
    final passCtrl = TextEditingController(text: isEdit ? (user['password'] ?? '') : '');

    String selectedBranch = isEdit ? (user['branch'] ?? 'فرع السلام (الرئيسي)') : 'فرع السلام (الرئيسي)';
    String selectedRole = isEdit ? (user['role'] ?? 'admin') : 'admin';

    List<String> selectedPerms = [];
    if (isEdit && user['permissions_json'] != null) {
      try {
        final List<dynamic> list = jsonDecode(user['permissions_json']);
        selectedPerms = list.map((e) => e.toString()).toList();
      } catch (_) {}
    } else {
      selectedPerms = [
        'dashboard',
        'appointments',
        'waiting_room',
        'emr',
        'consultation',
        'billing',
        'inventory',
        'reports',
        'settings',
      ];
    }

    final List<Map<String, String>> allPermsKeys = [
      {'key': 'dashboard', 'label': 'لوحة التحكم والمؤشرات (Dashboard)'},
      {'key': 'appointments', 'label': 'جدول المواعيد والحجوزات (Appointments)'},
      {'key': 'waiting_room', 'label': 'شاشة الانتظار والاستقبال (Waiting Room)'},
      {'key': 'emr', 'label': 'الملف الطبي للمرضى (EMR & History)'},
      {'key': 'consultation', 'label': 'الكشف والروشتة الإلكترونية (Consultation)'},
      {'key': 'billing', 'label': 'الحسابات والفواتير والتحصيل (Billing & Invoices)'},
      {'key': 'inventory', 'label': 'مخزن الكواشف والمستلزمات (Inventory)'},
      {'key': 'reports', 'label': 'التقارير المالية والإحصائيات (Reports)'},
      {'key': 'settings', 'label': 'إعدادات النظام والمستخدمين (Settings & Users)'},
    ];

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AppDialog(
            title: isEdit ? 'تعديل حساب موظف وصلاحياته' : 'إضافة حساب جديد وتعيين الصلاحيات',
            subtitle: 'حدد بيانات الدخول والدور والصلاحيات المسموح بها للحساب',
            icon: Icons.manage_accounts_rounded,
            iconColor: AppColors.primary,
            maxWidth: 580,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: fullNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'الاسم الكامل *',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: usernameCtrl,
                  decoration: InputDecoration(
                    labelText: 'اسم المستخدم للدخول (Username) *',
                    prefixIcon: const Icon(Icons.account_circle_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور (Password) *',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedBranch,
                  decoration: InputDecoration(
                    labelText: 'فرع العيادة المخصص *',
                    prefixIcon: const Icon(Icons.storefront_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'فرع السلام (الرئيسي)', child: Text('فرع السلام (الرئيسي)')),
                    DropdownMenuItem(value: 'جميع الفروع (سوبر أدمن)', child: Text('جميع الفروع (سوبر أدمن)')),
                    DropdownMenuItem(value: 'فرع العيادة الخارجي', child: Text('فرع العيادة الخارجي')),
                  ],
                  onChanged: (val) => setModalState(() => selectedBranch = val!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: InputDecoration(
                    labelText: 'الدور والوظيفة *',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('سوبر أدمن (Super Admin)')),
                    DropdownMenuItem(value: 'doctor', child: Text('طبيب / مدير عيادة')),
                    DropdownMenuItem(value: 'receptionist', child: Text('طاقم الاستقبال (Receptionist)')),
                  ],
                  onChanged: (val) => setModalState(() => selectedRole = val!),
                ),
                const SizedBox(height: 16),
                const Text(
                  'تحديد صلاحيات وأقسام هذا الحساب في النظام:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                ...allPermsKeys.map((item) {
                  final String key = item['key']!;
                  final String label = item['label']!;
                  final bool isChecked = selectedPerms.contains(key);

                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(label, style: const TextStyle(fontSize: 13)),
                    value: isChecked,
                    onChanged: (val) {
                      setModalState(() {
                        if (val == true) {
                          selectedPerms.add(key);
                        } else {
                          selectedPerms.remove(key);
                        }
                      });
                    },
                  );
                }),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary))),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  if (usernameCtrl.text.isEmpty || passCtrl.text.isEmpty) return;

                  final userData = {
                    'username': usernameCtrl.text.trim(),
                    'password': passCtrl.text.trim(),
                    'full_name': fullNameCtrl.text.trim(),
                    'role': selectedRole,
                    'branch': selectedBranch,
                    'permissions_json': jsonEncode(selectedPerms),
                    'is_active': 1,
                  };

                  if (isEdit) {
                    await _viewModel.clinicCubit.updateUser({
                      'id': user['id'],
                      ...userData,
                    });
                  } else {
                    await _viewModel.clinicCubit.addUser(userData);
                  }

                  if (isEdit &&
                      SessionManager.instance.currentUser != null &&
                      SessionManager.instance.currentUser!['id'] == user['id']) {
                    SessionManager.instance.setUserSession({
                      ...SessionManager.instance.currentUser!,
                      ...userData,
                    });
                  }

                  if (dialogCtx.mounted) {
                    Navigator.of(dialogCtx).pop();
                  }
                  _viewModel.clinicCubit.fetchUsers();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit ? 'تم تحديث بيانات المستخدم وصلاحياته بنجاح!' : 'تم إنشاء الحساب وتعيين الصلاحيات بنجاح!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
                child: Text(isEdit ? 'حفظ التغييرات' : 'إنشاء الحساب', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}
