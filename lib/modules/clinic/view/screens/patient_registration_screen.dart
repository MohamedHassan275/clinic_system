import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/common/validators.dart';
import '../../../../core/common/widgets/app_dialog.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/enums/appointment_enums.dart';
import '../../../../core/enums/payment_enums.dart';
import '../../../../core/security/shift_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/cubit/clinic_cubit.dart';

class PatientRegistrationScreen extends StatefulWidget {
  final Map<String, dynamic>? initialPatient;

  const PatientRegistrationScreen({
    super.key,
    this.initialPatient,
  });

  /// Static helper to trigger patient registration modal or route
  static Future<int?> show(BuildContext context, {Map<String, dynamic>? initialPatient}) async {
    if (!ShiftGuard.checkShiftOrWarn(context)) return null;

    final media = MediaQuery.of(context);
    final bool isMobile = media.size.width < 600;

    if (isMobile) {
      return await Navigator.of(context).push<int>(
        MaterialPageRoute(
          builder: (_) => PatientRegistrationScreen(initialPatient: initialPatient),
        ),
      );
    } else {
      return await showDialog<int>(
        context: context,
        builder: (ctx) => PatientRegistrationScreen(initialPatient: initialPatient),
      );
    }
  }

  @override
  State<PatientRegistrationScreen> createState() => _PatientRegistrationScreenState();
}

class _PatientRegistrationScreenState extends State<PatientRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  late final TextEditingController _nameCtrl;
  late final TextEditingController _nationalIdCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _secondaryPhoneCtrl;
  late final TextEditingController _allergiesCtrl;
  late final TextEditingController _contractEntityNameCtrl;
  late final TextEditingController _policyNumberCtrl;
  late final TextEditingController _emergencyNameCtrl;
  late final TextEditingController _emergencyRelationCtrl;
  late final TextEditingController _emergencyPhoneCtrl;

  // Form State Variables
  late DateTime _dob;
  late PatientGender _gender;
  late String _bloodGroup;
  late String _femaleStatus;
  late PaymentMethod _contractType;
  final List<String> _selectedChronic = [];

  bool get isEditMode => widget.initialPatient != null;
  bool _isSaving = false;

  static const List<String> _chronicOptions = ['سكر', 'ضغط', 'كلى', 'سيولة', 'كبد', 'قلب', 'ربو'];

  @override
  void initState() {
    super.initState();
    final p = widget.initialPatient;

    _nameCtrl = TextEditingController(text: p?['name'] ?? '');
    _nationalIdCtrl = TextEditingController(text: p?['national_id'] ?? '');
    _phoneCtrl = TextEditingController(text: p?['phone'] ?? '');
    _secondaryPhoneCtrl = TextEditingController(text: p?['secondary_phone'] ?? '');
    _allergiesCtrl = TextEditingController(text: (p?['allergies'] == 'لا توجد') ? '' : (p?['allergies'] ?? ''));
    _contractEntityNameCtrl = TextEditingController(text: p?['contract_entity_name'] ?? '');
    _policyNumberCtrl = TextEditingController(text: p?['policy_number'] ?? '');
    _emergencyNameCtrl = TextEditingController(text: p?['emergency_name'] ?? '');
    _emergencyRelationCtrl = TextEditingController(text: p?['emergency_relation'] ?? '');
    _emergencyPhoneCtrl = TextEditingController(text: p?['emergency_phone'] ?? '');

    _dob = DateTime.now().subtract(const Duration(days: 365 * 30));
    if (p?['dob'] != null) {
      final parsed = DateTime.tryParse(p!['dob'].toString());
      if (parsed != null) _dob = parsed;
    }

    _gender = PatientGender.fromString(p?['gender']);
    _bloodGroup = p?['blood_group'] ?? 'O+';
    _femaleStatus = p?['female_status'] ?? 'طبيعي';
    _contractType = PaymentMethod.fromString(p?['contract_entity'] ?? p?['contract_type']);

    if (p?['chronic_diseases'] != null && p!['chronic_diseases'].toString().isNotEmpty) {
      final list = p['chronic_diseases'].toString().split(', ');
      _selectedChronic.addAll(list.where((item) => _chronicOptions.contains(item)));
    }

    sl<ClinicCubit>().fetchInsuranceCompanies();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nationalIdCtrl.dispose();
    _phoneCtrl.dispose();
    _secondaryPhoneCtrl.dispose();
    _allergiesCtrl.dispose();
    _contractEntityNameCtrl.dispose();
    _policyNumberCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyRelationCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    super.dispose();
  }

  int get _calculatedAge {
    final now = DateTime.now();
    int age = now.year - _dob.year;
    if (now.month < _dob.month || (now.month == _dob.month && now.day < _dob.day)) {
      age--;
    }
    return age.clamp(0, 120);
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameCtrl.clear();
    _nationalIdCtrl.clear();
    _phoneCtrl.clear();
    _secondaryPhoneCtrl.clear();
    _allergiesCtrl.clear();
    _contractEntityNameCtrl.clear();
    _policyNumberCtrl.clear();
    _emergencyNameCtrl.clear();
    _emergencyRelationCtrl.clear();
    _emergencyPhoneCtrl.clear();

    setState(() {
      _dob = DateTime.now().subtract(const Duration(days: 365 * 30));
      _gender = PatientGender.male;
      _bloodGroup = 'O+';
      _femaleStatus = 'طبيعي';
      _contractType = PaymentMethod.cash;
      _selectedChronic.clear();
    });
  }

  Future<void> _savePatient({bool addAnother = false}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final String name = _nameCtrl.text.trim();
    final String phone = _phoneCtrl.text.trim();

    final Map<String, dynamic> patientData = {
      if (isEditMode) 'id': widget.initialPatient!['id'],
      'name': name,
      'phone': phone,
      'national_id': _nationalIdCtrl.text.trim(),
      'secondary_phone': _secondaryPhoneCtrl.text.trim(),
      'age': _calculatedAge,
      'gender': _gender.dbValue,
      'dob': DateFormat('yyyy-MM-dd').format(_dob),
      'blood_group': _bloodGroup,
      'female_status': _gender == PatientGender.female ? _femaleStatus : 'طبيعي',
      'contract_entity': _contractType.dbValue,
      'contract_entity_name': _contractEntityNameCtrl.text.trim(),
      'policy_number': _policyNumberCtrl.text.trim(),
      'allergies': _allergiesCtrl.text.trim().isEmpty ? 'لا توجد' : _allergiesCtrl.text.trim(),
      'chronic_diseases': _selectedChronic.isEmpty ? 'لا توجد' : _selectedChronic.join('، '),
      'emergency_name': _emergencyNameCtrl.text.trim(),
      'emergency_relation': _emergencyRelationCtrl.text.trim(),
      'emergency_phone': _emergencyPhoneCtrl.text.trim(),
      'created_at': isEditMode ? widget.initialPatient!['created_at'] : DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
    };

    final cubit = sl<ClinicCubit>();
    if (isEditMode) {
      final result = await cubit.updatePatient(patientData);
      setState(() => _isSaving = false);
      result.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('خطأ أثناء التحديث: ${failure.message}'), backgroundColor: AppColors.error),
            );
          }
        },
        (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم تحديث بيانات المريض بنجاح'), backgroundColor: AppColors.success),
            );
            Navigator.of(context).pop(widget.initialPatient!['id']);
          }
        },
      );
    } else {
      final result = await cubit.addPatient(patientData);
      setState(() => _isSaving = false);
      result.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('خطأ أثناء الحفظ: ${failure.message}'), backgroundColor: AppColors.error),
            );
          }
        },
        (newId) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('تم تسجيل المريض الجديد بنجاح (رقم كود: #$newId)'), backgroundColor: AppColors.success),
            );
            if (addAnother) {
              _resetForm();
            } else {
              Navigator.of(context).pop(newId);
            }
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bool isMobile = media.size.width < 600;

    if (isMobile) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 1,
          title: Text(
            isEditMode ? 'تعديل ملف المريض' : 'تسجيل مريض جديد',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildFormContent(isTwoColumn: false),
                const SizedBox(height: 24),
                _buildActionButtons(isMobile: true),
              ],
            ),
          ),
        ),
      );
    }

    return AppDialog(
      title: isEditMode ? 'تعديل بيانات المريض والملف السريري' : 'تسجيل مريض جديد والتأسيس السريري',
        subtitle: isEditMode ? 'تحديث البيانات الديموغرافية والطبية للمريض' : 'أدخل البيانات الشخصية والسريرية لتسجيل المريض بالعيادة',
        icon: isEditMode ? Icons.edit_note_rounded : Icons.person_add_alt_1_rounded,
        iconColor: AppColors.primary,
        maxWidth: 760,
        content: Form(
          key: _formKey,
          child: SizedBox(
            height: media.size.height * 0.72,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(4.0),
              child: _buildFormContent(isTwoColumn: true),
            ),
          ),
        ),
        actions: [
          _buildActionButtons(isMobile: false),
        ],
      );
  }

  Widget _buildFormContent({required bool isTwoColumn}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Personal Identification Section
        _buildSectionHeader('1. البيانات الشخصية والهوية الوطنية', Icons.badge_outlined),
        const SizedBox(height: 10),
        TextFormField(
          controller: _nameCtrl,
          validator: AppValidators.name,
          decoration: const InputDecoration(
            labelText: 'الاسم الكامل باللغة العربية أو الإنجليزية *',
            prefixIcon: Icon(Icons.person),
          ),
        ),
        const SizedBox(height: 12),
        if (isTwoColumn)
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  validator: AppValidators.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف الأساسي (11 رقم) *',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _nationalIdCtrl,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null; // Optional if not strict, or:
                    return AppValidators.nationalId(v);
                  },
                  decoration: const InputDecoration(labelText: 'الرقم القومي (14 رقم) / جواز السفر *', prefixIcon: Icon(Icons.credit_card)),
                ),
              ),
            ],
          )
        else ...[
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            validator: AppValidators.phone,
            decoration: const InputDecoration(labelText: 'رقم الهاتف الأساسي (11 رقم) *', prefixIcon: Icon(Icons.phone)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nationalIdCtrl,
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              return AppValidators.nationalId(v);
            },
            decoration: const InputDecoration(labelText: 'الرقم القومي (14 رقم) / جواز السفر *', prefixIcon: Icon(Icons.credit_card)),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dob,
                    firstDate: DateTime(1920),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _dob = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'تاريخ الميلاد *', prefixIcon: Icon(Icons.cake)),
                  child: Text(DateFormat('yyyy-MM-dd').format(_dob)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
              child: Text('السن: $_calculatedAge سنة', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _secondaryPhoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'رقم هاتف إضافي / أرضي (إختياري)', prefixIcon: Icon(Icons.phone_paused)),
        ),
        const SizedBox(height: 20),

        // 2. Clinical Demographics & Conditions Section
        _buildSectionHeader('2. البيانات السريرية وفصيلة الدم', Icons.local_hospital_outlined),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<PatientGender>(
                initialValue: _gender,
                decoration: const InputDecoration(labelText: 'الجنس (النوع) *'),
                items: PatientGender.values.map((g) {
                  return DropdownMenuItem(value: g, child: Text(g.displayName));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _gender = val);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _bloodGroup,
                decoration: const InputDecoration(labelText: 'فصيلة الدم'),
                items: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-', 'غير محدد'].map((bg) {
                  return DropdownMenuItem(value: bg, child: Text(bg));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _bloodGroup = val);
                },
              ),
            ),
          ],
        ),
        if (_gender == PatientGender.female) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _femaleStatus,
            decoration: const InputDecoration(labelText: 'الحالة الفسيولوجية للأنثى'),
            items: const [
              DropdownMenuItem(value: 'طبيعي', child: Text('طبيعي')),
              DropdownMenuItem(value: 'حامل', child: Text('حامل')),
              DropdownMenuItem(value: 'مرضع', child: Text('مرضع')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _femaleStatus = val);
            },
          ),
        ],
        const SizedBox(height: 14),
        const Text('الأمراض المزمنة المسجلة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _chronicOptions.map((ch) {
            final isSel = _selectedChronic.contains(ch);
            return FilterChip(
              selected: isSel,
              label: Text(ch),
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _selectedChronic.add(ch);
                  } else {
                    _selectedChronic.remove(ch);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _allergiesCtrl,
          decoration: const InputDecoration(
            labelText: 'الحساسيات المفرطة (أغذية أو أدوية)',
            hintText: 'مثال: حساسيه بنسلين، أسبرين، ألبان',
            prefixIcon: Icon(Icons.warning_amber_rounded),
          ),
        ),
        const SizedBox(height: 20),

        // 3. Contract & Insurance Section
        _buildSectionHeader('3. فئة التعاقد والتأمين الصحي', Icons.health_and_safety_outlined),
        const SizedBox(height: 10),
        DropdownButtonFormField<PaymentMethod>(
          initialValue: _contractType,
          decoration: const InputDecoration(labelText: 'نوع التعاقد / الفئة *'),
          items: const [
            DropdownMenuItem(value: PaymentMethod.cash, child: Text('نقدي (خاص)')),
            DropdownMenuItem(value: PaymentMethod.insurance, child: Text('تأمين صحي')),
            DropdownMenuItem(value: PaymentMethod.card, child: Text('شركة تعاقد خاص')),
            DropdownMenuItem(value: PaymentMethod.transfer, child: Text('نقابة المهندسين / الأطباء')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _contractType = val);
          },
        ),
        if (_contractType != PaymentMethod.cash) ...[
          const SizedBox(height: 12),
          if (isTwoColumn)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _contractEntityNameCtrl,
                    decoration: const InputDecoration(labelText: 'اسم شركة التأمين / الجهة *'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _policyNumberCtrl,
                    decoration: const InputDecoration(labelText: 'رقم الكارت / البوليصة التأمينية'),
                  ),
                ),
              ],
            )
          else ...[
            TextFormField(
              controller: _contractEntityNameCtrl,
              decoration: const InputDecoration(labelText: 'اسم شركة التأمين / الجهة *'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _policyNumberCtrl,
              decoration: const InputDecoration(labelText: 'رقم الكارت / البوليصة التأمينية'),
            ),
          ],
        ],
        const SizedBox(height: 20),

        // 4. Emergency Contact Section
        _buildSectionHeader('4. جهة الاتصال عند الطوارئ', Icons.contact_emergency_outlined),
        const SizedBox(height: 10),
        if (isTwoColumn)
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _emergencyNameCtrl,
                  decoration: const InputDecoration(labelText: 'اسم شخص الطوارئ'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _emergencyRelationCtrl,
                  decoration: const InputDecoration(labelText: 'صلة القرابة (أب، أم، زوج...)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _emergencyPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'هاتف الطوارئ'),
                ),
              ),
            ],
          )
        else ...[
          TextFormField(
            controller: _emergencyNameCtrl,
            decoration: const InputDecoration(labelText: 'اسم شخص الطوارئ'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emergencyRelationCtrl,
            decoration: const InputDecoration(labelText: 'صلة القرابة (أب، أم، زوج...)'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emergencyPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'هاتف الطوارئ'),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
      ],
    );
  }

  Widget _buildActionButtons({required bool isMobile}) {
    if (_isSaving) {
      return const Center(child: CircularProgressIndicator());
    }

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _savePatient(addAnother: false),
            icon: const Icon(Icons.check, color: Colors.white),
            label: Text(isEditMode ? 'تحديث بيانات المريض' : 'حفظ وتسجيل المريض', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          if (!isEditMode) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _savePatient(addAnother: true),
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('حفظ وإضافة مريض آخر'),
            ),
          ],
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        if (!isEditMode) ...[
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _savePatient(addAnother: true),
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text('حفظ وإضافة مريض آخر'),
          ),
        ],
        const SizedBox(width: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => _savePatient(addAnother: false),
          icon: const Icon(Icons.check, color: Colors.white, size: 18),
          label: Text(isEditMode ? 'تحديث البيانات' : 'حفظ المريض', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
