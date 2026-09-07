import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/security/session_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../shared/cubit/block_builder_widget.dart';
import '../../data/cubit/clinic_cubit.dart';
import '../clinic_view_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final ClinicViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = sl<ClinicViewModel>()..updateRefresh(() {
      if (mounted) setState(() {});
    });
    _viewModel.clinicCubit.fetchUsers();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Page Header
            const Row(
              children: [
                Icon(Icons.arrow_back, color: AppColors.textPrimary),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إدارة المستخدمين والأدوار والصلاحيات (RBAC)',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'التحكم في وصول الأدمنز والطاقم الطبي وأقسام النظام',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Top Hero Card (Super Admin Access Banner matching Image 1)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: () => _showUserDialog(context),
                    icon: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 18),
                    label: const Text('إضافة مستخدم جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'صلاحيات التحكم للسوبر أدمن (Super Admin Access)',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'يمكنك إنشاء مستخدمين جدد وتخصيص صلاحيات محددة لمنع أو منح الوصول لأقسام العيادة.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.admin_panel_settings_outlined, color: AppColors.primary, size: 28),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Users List Section Header
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'قائمة حسابات المستخدمين المسجلة بالنظام',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 16),

            // Users Dynamic List
            BlockBuilderWidget<ClinicCubit, ClinicApiType>(
              types: const [ClinicApiType.getUsers],
              body: (_) => _buildUsersList(),
              loading: (_) => const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersList() {
    final users = _viewModel.clinicCubit.usersList;
    if (users.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text('لا يوجد مستخدمين مسجلين حالياً في قاعدة البيانات', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return Column(
      children: users.map((user) {
        final String role = user['role'] ?? 'receptionist';
        final String fullName = user['full_name'] ?? 'مستخدم غير معروف';
        final String username = user['username'] ?? '';
        final String branch = user['branch'] ?? 'فرع السلام (الرئيسي)';
        final bool isAdmin = role == 'admin';

        List<String> perms = [];
        try {
          final raw = user['permissions_json'];
          if (raw is String) perms = List<String>.from(jsonDecode(raw));
        } catch (_) {}

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              // Action buttons on Left
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    tooltip: 'حذف المستخدم',
                    onPressed: () => _confirmDeleteUser(context, user),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: () => _showUserDialog(context, user: user),
                    icon: const Icon(Icons.shield_outlined, color: Colors.white, size: 16),
                    label: const Text('تعديل الصلاحيات والأقسام', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const Spacer(),
              // User Details on Right
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: isAdmin ? Colors.blueGrey[100] : AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isAdmin ? 'سوبر أدمن (Super Admin)' : (role == 'doctor' ? 'طبيب معالج' : 'طاقم الاستقبال'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isAdmin ? Colors.blueGrey[900] : AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        fullName.startsWith('د.') ? fullName : 'د. $fullName',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'اسم المستخدم: $username · الفرع: $branch · الصلاحيات المتاحة: ${perms.length} أقسام',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 22,
                backgroundColor: isAdmin ? const Color(0xFF0F172A) : AppColors.primary,
                child: Text(
                  fullName.isNotEmpty ? fullName.replaceAll('د.', '').trim()[0] : 'م',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _confirmDeleteUser(BuildContext context, Map<String, dynamic> user) {
    if (user['username'] == 'mo_hassan') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن حذف حساب السوبر أدمن الرئيسي!'), backgroundColor: AppColors.error),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد حذف الحساب'),
        content: Text('هل أنت تأكد من رغبتك في حذف حساب المستخدم "${user['full_name']}" من النظام نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await _viewModel.clinicCubit.deleteUser(user['id'] as int);
              if (dialogCtx.mounted) {
                Navigator.of(dialogCtx).pop();
              }
              _viewModel.clinicCubit.fetchUsers();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حذف حساب المستخدم بنجاح!'), backgroundColor: AppColors.success),
                );
              }
            },
            child: const Text('حذف الحساب', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showUserDialog(BuildContext context, {Map<String, dynamic>? user}) {
    final bool isEdit = user != null;
    final fullNameCtrl = TextEditingController(text: isEdit ? user['full_name'] : '');
    final usernameCtrl = TextEditingController(text: isEdit ? user['username'] : '');
    final passCtrl = TextEditingController(text: isEdit ? user['password'] : '');

    String selectedBranch = isEdit ? (user['branch'] ?? 'فرع السلام (الرئيسي)') : 'فرع السلام (الرئيسي)';
    String selectedRole = isEdit ? (user['role'] ?? 'receptionist') : 'receptionist';

    final allPermsKeys = [
      {'key': 'dashboard', 'label': 'الرئيسية (لوحة التحكم)'},
      {'key': 'appointments', 'label': 'جدول المواعيد والحجوزات'},
      {'key': 'waiting_room', 'label': 'شاشة الانتظار والاستقبال'},
      {'key': 'emr', 'label': 'الملف الطبي للمرضى (EMR)'},
      {'key': 'consultation', 'label': 'الكشف والروشتة الإلكترونية'},
      {'key': 'billing', 'label': 'الحسابات والفواتير'},
      {'key': 'inventory', 'label': 'مخزن المستلزمات الطبية'},
      {'key': 'reports', 'label': 'التقارير والإحصائيات'},
      {'key': 'settings', 'label': 'الإعدادات وإدارة المستخدمين'},
    ];

    List<String> selectedPerms = [];
    if (isEdit) {
      try {
        final raw = user['permissions_json'];
        if (raw is String) selectedPerms = List<String>.from(jsonDecode(raw));
      } catch (_) {}
    } else {
      selectedPerms = ['dashboard', 'appointments', 'waiting_room', 'billing'];
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 540,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dialog Title matching Image 2
                  Center(
                    child: Text(
                      isEdit ? 'تعديل حساب مستخدم وتحديد الصلاحيات' : 'إنشاء حساب مستخدم جديد وتحديد الصلاحيات',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Full Name Field
                  TextField(
                    controller: fullNameCtrl,
                    decoration: InputDecoration(
                      labelText: 'الاسم الكامل / مين هو *',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Username Field
                  TextField(
                    controller: usernameCtrl,
                    decoration: InputDecoration(
                      labelText: 'اسم المستخدم للدخول (Username) *',
                      prefixIcon: const Icon(Icons.account_circle_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Password Field
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'الرقم السري للدخول (Password) *',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Branch Dropdown Field
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

                  // Role Dropdown Field
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
                  const SizedBox(height: 20),

                  // Permissions Section Title
                  const Text(
                    'تحديد صلاحيات وأقسام هذا الحساب في النظام:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),

                  // Checkboxes List
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
                  const SizedBox(height: 20),

                  // Modal Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        child: const Text('إلغاء'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

                          // Refresh active session if editing logged-in user
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
