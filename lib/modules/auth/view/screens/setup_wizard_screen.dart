import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/common/validators.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/security/password_hasher.dart';
import '../../../../core/security/session_manager.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _currentStep = 0;
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();

  // Step 1: Clinic Data
  final _clinicNameController = TextEditingController(text: 'عيادتي التخصصية');
  final _legalNameController = TextEditingController();
  final _addressController = TextEditingController(text: 'الفرع الرئيسي');
  final _clinicPhoneController = TextEditingController(text: '01000000000');
  final _clinicEmailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _commercialRegisterController = TextEditingController();
  String? _logoPath;

  // Step 2: Super Admin Account
  final _adminFullNameController = TextEditingController(text: 'محمد حسن');
  final _adminUsernameController = TextEditingController(text: 'mo_hassan');
  final _adminPasswordController = TextEditingController(text: '12345678');
  final _confirmPasswordController = TextEditingController(text: '12345678');
  final _adminPhoneController = TextEditingController();
  final _adminEmailController = TextEditingController();

  // Step 3: Initial Settings
  String _selectedCurrency = 'EGP';
  String _selectedLanguage = 'ar';
  final _workingHoursController = TextEditingController(text: '09:00 - 21:00');
  final _workingDaysController = TextEditingController(text: 'السبت - الخميس');
  String _selectedTimezone = 'Africa/Cairo (+02:00)';
  final String _selectedDateFormat = 'yyyy-MM-dd';

  bool _isSaving = false;

  @override
  void dispose() {
    _clinicNameController.dispose();
    _legalNameController.dispose();
    _addressController.dispose();
    _clinicPhoneController.dispose();
    _clinicEmailController.dispose();
    _websiteController.dispose();
    _taxIdController.dispose();
    _commercialRegisterController.dispose();
    _adminFullNameController.dispose();
    _adminUsernameController.dispose();
    _adminPasswordController.dispose();
    _confirmPasswordController.dispose();
    _adminPhoneController.dispose();
    _adminEmailController.dispose();
    _workingHoursController.dispose();
    _workingDaysController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_step1FormKey.currentState!.validate()) return;
    } else if (_currentStep == 1) {
      if (!_step2FormKey.currentState!.validate()) return;
      if (_adminPasswordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('كلمة المرور وتأكيد كلمة المرور غير متطابقين'), backgroundColor: Colors.red),
        );
        return;
      }
    } else if (_currentStep == 2) {
      if (!_step3FormKey.currentState!.validate()) return;
    }

    if (_currentStep < 3) {
      setState(() {
        _currentStep += 1;
      });
    } else {
      _saveSetupAndFinish();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep -= 1;
      });
    }
  }

  void _goToStep(int stepIndex) {
    if (stepIndex >= 0 && stepIndex <= 3) {
      setState(() {
        _currentStep = stepIndex;
      });
    }
  }

  Future<void> _saveSetupAndFinish() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final db = await DatabaseHelper.instance.database;
      final nowStr = DateTime.now().toIso8601String();

      // 1. Save or Update Default Clinic (id = 1)
      await db.rawInsert('''
        INSERT OR REPLACE INTO clinics (
          id, name, address, phone, email, logo_path, currency, subscription_plan, is_active, created_at, updated_at
        ) VALUES (1, ?, ?, ?, ?, ?, ?, 'pro', 1, ?, ?)
      ''', [
        _clinicNameController.text.trim(),
        _addressController.text.trim(),
        _clinicPhoneController.text.trim(),
        _clinicEmailController.text.trim(),
        _logoPath,
        _selectedCurrency,
        nowStr,
        nowStr,
      ]);

      // 2. Hash Password using BCrypt and Save/Update Super Admin User
      final hashedPassword = PasswordHasher.hashPassword(_adminPasswordController.text);
      final allPermissions = jsonEncode([
        'dashboard',
        'appointments',
        'waiting_room',
        'emr',
        'consultation',
        'billing',
        'inventory',
        'reports',
        'settings',
      ]);

      final userId = await db.insert('users', {
        'clinic_id': 1,
        'username': _adminUsernameController.text.trim(),
        'password': null, // Plain text nullified for new setup
        'password_hash': hashedPassword,
        'full_name': _adminFullNameController.text.trim(),
        'role': 'admin',
        'branch': 'جميع الفروع (سوبر أدمن)',
        'permissions_json': allPermissions,
        'is_active': 1,
        'created_at': nowStr,
        'updated_at': nowStr,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // 3. Save Initial Settings
      final settingsMap = {
        'currency': _selectedCurrency,
        'language': _selectedLanguage,
        'working_hours': _workingHoursController.text.trim(),
        'working_days': _workingDaysController.text.trim(),
        'timezone': _selectedTimezone,
        'date_format': _selectedDateFormat,
        'legal_name': _legalNameController.text.trim(),
        'tax_id': _taxIdController.text.trim(),
        'commercial_register': _commercialRegisterController.text.trim(),
      };

      for (var entry in settingsMap.entries) {
        await db.rawInsert('''
          INSERT OR REPLACE INTO settings (clinic_id, key, value, updated_at)
          VALUES (1, ?, ?, ?)
        ''', [entry.key, entry.value, nowStr]);
      }

      // 4. Set Active Session for the created Super Admin
      final userMap = {
        'id': userId,
        'clinic_id': 1,
        'username': _adminUsernameController.text.trim(),
        'full_name': _adminFullNameController.text.trim(),
        'role': 'admin',
        'permissions_json': allPermissions,
      };
      SessionManager.instance.setUserSession(userMap);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إعداد النظام والعيادة بنجاح!'), backgroundColor: AppColors.success),
        );
        Navigator.of(context).pushReplacementNamed('/shell');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء حفظ الإعدادات: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('معالج إعداد النظام والعيادة لأول مرة (Setup Wizard)'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 2,
      ),
      body: Row(
        children: [
          // Side Stepper Sidebar
          Container(
            width: 280,
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.local_hospital_rounded, color: AppColors.secondary, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Clinic System', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildSidebarStep(0, 'بيانات العيادة', 'الاسم، العنوان، الهاتف واللوجو', Icons.storefront),
                const SizedBox(height: 20),
                _buildSidebarStep(1, 'مدير النظام', 'حساب السوبر أدمن وكلمة المرور', Icons.admin_panel_settings),
                const SizedBox(height: 20),
                _buildSidebarStep(2, 'الإعدادات الأولية', 'العملة، اللغة، وساعات العمل', Icons.settings_suggest),
                const SizedBox(height: 20),
                _buildSidebarStep(3, 'مراجعة وتأكيد', 'مراجعة كافة البيانات قبل الحفظ', Icons.fact_check_outlined),
                const Spacer(),
                const Text(
                  'إصدار النظام: 5.0.0\nمؤمن بنظام تشفير BCrypt & DPAPI',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),

          // Main Step Form Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(36),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_currentStep == 0) _buildStep1Form(),
                      if (_currentStep == 1) _buildStep2Form(),
                      if (_currentStep == 2) _buildStep3Form(),
                      if (_currentStep == 3) _buildStep4Review(),
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (_currentStep > 0)
                            OutlinedButton.icon(
                              onPressed: _isSaving ? null : _previousStep,
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('السابق'),
                            ),
                          const Spacer(),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            ),
                            onPressed: _isSaving ? null : _nextStep,
                            icon: _isSaving
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Icon(_currentStep == 3 ? Icons.check_circle : Icons.arrow_forward),
                            label: Text(_currentStep == 3 ? 'تأكيد وحفظ الإعدادات النهائية' : 'التالي'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarStep(int index, String title, String subtitle, IconData icon) {
    final bool isActive = _currentStep == index;
    final bool isCompleted = _currentStep > index;

    return InkWell(
      onTap: () => _goToStep(index),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isActive ? AppColors.secondary : (isCompleted ? AppColors.success : Colors.white10),
              child: Icon(isCompleted ? Icons.check : icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isActive ? Colors.white : (isCompleted ? Colors.white70 : Colors.white38),
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                  Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1Form() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الخطوة 1: بيانات العيادة والفرع', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('أدخل البيانات الأساسية للعيادة لتخصيص الهوية والطباعة على الفواتير والروشتات.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _clinicNameController,
                  decoration: const InputDecoration(labelText: 'اسم العيادة الرسمي *', prefixIcon: Icon(Icons.storefront)),
                  validator: (v) => AppValidators.required(v, 'اسم العيادة مطلوب'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _legalNameController,
                  decoration: const InputDecoration(labelText: 'الاسم القانوني / الشركة', prefixIcon: Icon(Icons.gavel)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _clinicPhoneController,
                  decoration: const InputDecoration(labelText: 'رقم هاتف العيادة *', prefixIcon: Icon(Icons.phone)),
                  validator: (v) => AppValidators.phone(v),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _clinicEmailController,
                  decoration: const InputDecoration(labelText: 'البريد الإلكتروني للعيادة', prefixIcon: Icon(Icons.email)),
                  validator: (v) => v != null && v.isNotEmpty ? AppValidators.email(v) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(labelText: 'العنوان التفصيلي *', prefixIcon: Icon(Icons.location_on)),
            validator: (v) => AppValidators.required(v, 'العنوان مطلوب'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _taxIdController,
                  decoration: const InputDecoration(labelText: 'الرقم الضريبي', prefixIcon: Icon(Icons.receipt_long)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _commercialRegisterController,
                  decoration: const InputDecoration(labelText: 'رقم السجل التجاري', prefixIcon: Icon(Icons.business_center)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Form() {
    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الخطوة 2: إنشاء حساب المدير المسئول (Super Admin)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('سيتم تشفير كلمة المرور وتعيين الصلاحيات الكاملة للتحكم في كافة أقسام العيادة.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _adminFullNameController,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل للمدير *', prefixIcon: Icon(Icons.person)),
                  validator: (v) => AppValidators.name(v),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _adminUsernameController,
                  decoration: const InputDecoration(labelText: 'اسم المستخدم للتدخيل (Username) *', prefixIcon: Icon(Icons.account_circle)),
                  validator: (v) => AppValidators.minLength(v, 4, 'اسم المستخدم يجب ألا يقل عن 4 أحرف'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _adminPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'كلمة المرور *', prefixIcon: Icon(Icons.lock)),
                  validator: (v) => AppValidators.password(v, strict: false),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور *', prefixIcon: Icon(Icons.lock_clock)),
                  validator: (v) => AppValidators.required(v, 'يرجى تأكيد كلمة المرور'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Form() {
    return Form(
      key: _step3FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الخطوة 3: الإعدادات الأولية للنظام', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('حدد العملة واللغة وساعات العمل الأساسية لتشغيل المواعيد والفواتير.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedCurrency,
                  decoration: const InputDecoration(labelText: 'عملة العيادة الرئيسية', prefixIcon: Icon(Icons.monetization_on)),
                  items: const [
                    DropdownMenuItem(value: 'EGP', child: Text('جنيه مصري (EGP)')),
                    DropdownMenuItem(value: 'SAR', child: Text('ريال سعودي (SAR)')),
                    DropdownMenuItem(value: 'USD', child: Text('دولار أمريكي (USD)')),
                  ],
                  onChanged: (v) => setState(() => _selectedCurrency = v!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedLanguage,
                  decoration: const InputDecoration(labelText: 'لغة الواجهة', prefixIcon: Icon(Icons.language)),
                  items: const [
                    DropdownMenuItem(value: 'ar', child: Text('العربية (Arabic)')),
                    DropdownMenuItem(value: 'en', child: Text('الإنجليزية (English)')),
                  ],
                  onChanged: (v) => setState(() => _selectedLanguage = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _workingHoursController,
                  decoration: const InputDecoration(labelText: 'ساعات العمل اليومية *', prefixIcon: Icon(Icons.access_time)),
                  validator: (v) => AppValidators.required(v, 'ساعات العمل مطلوبة'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _workingDaysController,
                  decoration: const InputDecoration(labelText: 'أيام العمل الأسبوعية *', prefixIcon: Icon(Icons.calendar_month)),
                  validator: (v) => AppValidators.required(v, 'أيام العمل مطلوبة'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedTimezone,
            decoration: const InputDecoration(labelText: 'المنطقة الزمنية (Timezone)', prefixIcon: Icon(Icons.public)),
            items: const [
              DropdownMenuItem(value: 'Africa/Cairo (+02:00)', child: Text('القاهرة (Africa/Cairo +02:00)')),
              DropdownMenuItem(value: 'Asia/Riyadh (+03:00)', child: Text('الرياض (Asia/Riyadh +03:00)')),
              DropdownMenuItem(value: 'UTC (+00:00)', child: Text('التوقيت العالمي (UTC)')),
            ],
            onChanged: (v) => setState(() => _selectedTimezone = v!),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4Review() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الخطوة 4: مراجعة وتأكيد البيانات (Final Review)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        const Text('راجع البيانات التالية بعناية قبل اعتماد التثبيت والبدء الفعلي في استخدام النظام.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 24),

        // Summary Card 1: Clinic Info
        _buildSummaryCard(
          title: 'بيانات العيادة',
          icon: Icons.storefront,
          stepIndex: 0,
          items: [
            MapEntry('اسم العيادة', _clinicNameController.text),
            MapEntry('العنوان', _addressController.text),
            MapEntry('الهاتف', _clinicPhoneController.text),
            if (_clinicEmailController.text.isNotEmpty) MapEntry('البريد الإلكتروني', _clinicEmailController.text),
            if (_taxIdController.text.isNotEmpty) MapEntry('الرقم الضريبي', _taxIdController.text),
          ],
        ),
        const SizedBox(height: 16),

        // Summary Card 2: Super Admin Info
        _buildSummaryCard(
          title: 'مدير النظام (Super Admin)',
          icon: Icons.admin_panel_settings,
          stepIndex: 1,
          items: [
            MapEntry('الاسم الكامل', _adminFullNameController.text),
            MapEntry('اسم المستخدم', _adminUsernameController.text),
            MapEntry('تشفير كلمة المرور', 'BCrypt (10 Rounds Salt Enabled)'),
          ],
        ),
        const SizedBox(height: 16),

        // Summary Card 3: Settings Info
        _buildSummaryCard(
          title: 'الإعدادات الأولية',
          icon: Icons.settings_suggest,
          stepIndex: 2,
          items: [
            MapEntry('العملة', _selectedCurrency),
            MapEntry('اللغة', _selectedLanguage == 'ar' ? 'العربية' : 'English'),
            MapEntry('ساعات العمل', _workingHoursController.text),
            MapEntry('أيام العمل', _workingDaysController.text),
            MapEntry('المنطقة الزمنية', _selectedTimezone),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required IconData icon,
    required int stepIndex,
    required List<MapEntry<String, String>> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _goToStep(stepIndex),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('تعديل', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const Divider(height: 16),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text('${item.key}: ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    Text(item.value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
