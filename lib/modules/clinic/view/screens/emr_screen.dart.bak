import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/security/shift_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../shared/cubit/block_builder_widget.dart';
import '../../data/cubit/clinic_cubit.dart';
import '../clinic_view_model.dart';

class EMRScreen extends StatefulWidget {
  const EMRScreen({super.key});

  @override
  State<EMRScreen> createState() => _EMRScreenState();
}

class _EMRScreenState extends State<EMRScreen> with SingleTickerProviderStateMixin {
  late final ClinicViewModel _viewModel;
  Map<String, dynamic>? _selectedPatient;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _viewModel = sl<ClinicViewModel>()..updateRefresh(() {
      if (mounted) setState(() {});
    });
    _viewModel.clinicCubit.fetchPatients();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الملف الطبي للمرضى (EMR)', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('السجل الطبي الشامل، التاريخ المرضي السريري، نتائج التحاليل، والروشتات', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (ShiftGuard.checkShiftOrWarn(context)) {
                      _showAddPatientDialog(context);
                    }
                  },
                  icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                  label: const Text('تسجيل مريض جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              controller: _viewModel.patientSearchController,
              decoration: InputDecoration(
                hintText: 'البحث باسم المريض، رقم الهاتف، أو الرقم القومي...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (q) {
                _viewModel.clinicCubit.fetchPatients(query: q);
              },
            ),
            const SizedBox(height: 16),

            // Main Split Workspace
            Expanded(
              child: Row(
                children: [
                  // Patients Master List (Right Side 35%)
                  Expanded(
                    flex: 3,
                    child: BlockBuilderWidget<ClinicCubit, ClinicApiType>(
                      types: const [ClinicApiType.getPatients],
                      body: (_) => _buildPatientsList(),
                      loading: (_) => const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Patient Detailed Clinical Workspace (Left Side 65%)
                  Expanded(
                    flex: 6,
                    child: _selectedPatient == null
                        ? Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.folder_shared_outlined, size: 64, color: AppColors.textLight),
                                  SizedBox(height: 16),
                                  Text('اختر مريضاً من القائمة لعرض ملفه الطبي الشامل وتنبيهاته', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                                ],
                              ),
                            ),
                          )
                        : _buildPatientClinicalDashboard(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientsList() {
    final list = _viewModel.clinicCubit.patients;
    if (list.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text('لا يوجد مرضى مطبقون مع البحث')),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        itemCount: list.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final p = list[index];
          final isSelected = _selectedPatient != null && _selectedPatient!['id'] == p['id'];
          final String bloodGroup = p['blood_group'] ?? 'غير محدد';

          final String phoneStr = (p['phone'] != null && p['phone'].toString().isNotEmpty) ? p['phone'].toString() : 'غير مسجل';
          final String genderStr = (p['gender'] != null && p['gender'].toString().isNotEmpty) ? p['gender'].toString() : 'غير محدد';

          return ListTile(
            selected: isSelected,
            selectedTileColor: AppColors.primaryLight,
            leading: CircleAvatar(
              backgroundColor: isSelected ? AppColors.primary : Colors.teal[50],
              child: Text(
                p['name'] != null && p['name'].toString().isNotEmpty ? p['name'][0] : 'م',
                style: TextStyle(color: isSelected ? Colors.white : AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
            title: Row(
              children: [
                Expanded(child: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                if (bloodGroup != 'غير محدد')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(6)),
                    child: Text(bloodGroup, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
              ],
            ),
            subtitle: Text('الهاتف: $phoneStr | السن: ${p['age'] ?? '-'} سنة | $genderStr'),
            onTap: () {
              setState(() {
                _selectedPatient = p;
              });
              _viewModel.clinicCubit.fetchPatientRecord(p['id'] as int);
            },
          );
        },
      ),
    );
  }

  Widget _buildPatientClinicalDashboard() {
    final p = _selectedPatient!;
    final String bloodGroup = p['blood_group'] ?? 'O+';
    final String allergies = p['allergies'] ?? 'لا توجد حساسية معروفة';
    final String chronic = p['chronic_diseases'] ?? 'لا توجد أمراض مزمنة مسجلة';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Patient Identity Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      p['name'] != null && p['name'].toString().isNotEmpty ? p['name'][0] : 'م',
                      style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(p['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Colors.red[600], borderRadius: BorderRadius.circular(8)),
                              child: Text(bloodGroup, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                              child: Text('${p['age'] ?? 30} سنة · ${p['gender'] ?? 'ذكر'}', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'الهاتف: ${p['phone'] ?? 'غير مسجل'} | الرقم القومي: ${p['national_id'] ?? 'غير مسجل'} | التعاقد: ${p['contract_entity'] ?? 'نقدي (خاص)'}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                    onPressed: () => _showAddLabResultDialog(context, p['id'] as int),
                    icon: const Icon(Icons.science, color: Colors.white, size: 16),
                    label: const Text('إضافة نتيجة فحص', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Critical Medical Alerts Banner (Top Warning Bar)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        const Text('الحساسية:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 13)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(6)),
                          child: Text(allergies, style: TextStyle(color: Colors.red[900], fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const SizedBox(width: 16),
                        const Text('الأمراض المزمنة:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 13)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(6)),
                          child: Text(chronic, style: TextStyle(color: Colors.amber[900], fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Categorized Multi-Section Tabbed View
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(icon: Icon(Icons.analytics_outlined), text: 'السجل التراكمي للتحاليل (Lab Trends)'),
                Tab(icon: Icon(Icons.receipt_long), text: 'الروشتات والملفات المرفقة'),
                Tab(icon: Icon(Icons.medication_liquid), text: 'التاريخ الدوائي والملاحظات'),
              ],
            ),
            const SizedBox(height: 12),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Cumulative Lab History & Trends
                  BlockBuilderWidget<ClinicCubit, ClinicApiType>(
                    types: const [ClinicApiType.getPatientRecord],
                    body: (_) => _buildLabResultsTab(),
                    loading: (_) => const Center(child: CircularProgressIndicator()),
                  ),
                  // Tab 2: Prescriptions & Attachments
                  BlockBuilderWidget<ClinicCubit, ClinicApiType>(
                    types: const [ClinicApiType.getPatientRecord],
                    body: (_) => _buildAttachmentsTab(p['id'] as int),
                    loading: (_) => const Center(child: CircularProgressIndicator()),
                  ),
                  // Tab 3: Ongoing Medications & Notes
                  _buildMedicationsAndNotesTab(p),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabResultsTab() {
    final record = _viewModel.clinicCubit.selectedPatientRecord;
    final labs = record != null ? (record['lab_results'] as List? ?? []) : [];

    if (labs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.science_outlined, size: 48, color: AppColors.textLight),
            const SizedBox(height: 8),
            const Text('لا توجد نتائج فحوصات معملية سابقة مسجلة للمريض', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _showAddLabResultDialog(context, _selectedPatient!['id'] as int),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('إضافة نتيجة فحص جديدة', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: labs.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final lab = labs[index];
        final String status = lab['status'] ?? 'طبيعي';

        Color flagColor = AppColors.success;
        if (status == 'مرتفع') flagColor = AppColors.error;
        if (status == 'منخفض') flagColor = Colors.blue;

        return ListTile(
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: flagColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(status, style: TextStyle(color: flagColor, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          title: Text(lab['test_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('تاريخ الفحص: ${lab['test_date']} | المدى المرجعي: ${lab['reference_range']}'),
          trailing: Text(
            '${lab['measured_value']} ${lab['unit']}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: flagColor),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentsTab(int patientId) {
    final record = _viewModel.clinicCubit.selectedPatientRecord;
    final prescs = record != null ? (record['prescriptions'] as List? ?? []) : [];
    final attach = record != null ? (record['attachments'] as List? ?? []) : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('عدد الروشتات المسجلة: ${prescs.length} | عدد المستندات المرفقة: ${attach.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: () => _showAddAttachmentDialog(context, patientId),
              icon: const Icon(Icons.attach_file, color: Colors.white, size: 16),
              label: const Text('إرفاق مستند جديد', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              if (prescs.isNotEmpty) ...[
                const Text('الروشتات الإلكترونية الصادرة:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 8),
                ...prescs.map((pr) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.description, color: AppColors.primary),
                      title: Text('تشخيص: ${pr['diagnosis']}'),
                      subtitle: Text('تاريخ: ${pr['created_at']} | ملاحظات: ${pr['notes'] ?? '-'}'),
                    ),
                  );
                }),
              ],
              if (attach.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('المرفقات والتقارير الخارجية:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary)),
                const SizedBox(height: 8),
                ...attach.map((at) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.image, color: AppColors.secondary),
                      title: Text(at['file_name'] ?? 'مستند مرفق'),
                      subtitle: Text('تاريخ الإرفاق: ${at['created_at']}'),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationsAndNotesTab(Map<String, dynamic> p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الأدوية المؤثرة على التحاليل وموانع الاستعمال:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
          child: const Text('لا توجد أدوية تتعارض مع نتائج الكواشف المعملية حالياً', style: TextStyle(color: Colors.blue)),
        ),
        const SizedBox(height: 16),
        const Text('التاريخ المرضي والملاحظات السريرية:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: Text(p['medical_history'] ?? 'لا توجد ملاحظات سريرية مؤرخة'),
          ),
        ),
      ],
    );
  }

  void _showAddPatientDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final nationalIdCtrl = TextEditingController();
    final emergencyPhoneCtrl = TextEditingController();

    DateTime dob = DateTime.now().subtract(const Duration(days: 365 * 30));
    String gender = 'ذكر';
    String bloodGroup = 'O+';
    String femaleStatus = 'طبيعي';
    String contractEntity = 'نقدي (خاص)';

    final List<String> chronicList = ['سكر', 'ضغط', 'كلى', 'سيولة', 'كبد'];
    final List<String> selectedChronic = [];
    final allergiesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final int ageYears = DateTime.now().year - dob.year;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: 580,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: Text(
                        'إضافة مريض جديد والتسجيل السريري',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 1: Personal Identification
                    const Text('1. البيانات الشخصية والهوية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'الاسم بالكامل *', prefixIcon: Icon(Icons.person)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(labelText: 'رقم الهاتف *', prefixIcon: Icon(Icons.phone)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: nationalIdCtrl,
                            decoration: const InputDecoration(labelText: 'الرقم القومي / جواز السفر', prefixIcon: Icon(Icons.badge)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Date of birth & Age badge
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dob,
                                firstDate: DateTime(1920),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setModalState(() => dob = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'تاريخ الميلاد', prefixIcon: Icon(Icons.cake)),
                              child: Text(DateFormat('yyyy-MM-dd').format(dob)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
                          child: Text('السن: $ageYears سنة', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Section 2: Clinical Demographics & Lab Reference Ranges
                    const Text('2. البيانات السريرية وفصيلة الدم (Reference Ranges):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: gender,
                            decoration: const InputDecoration(labelText: 'النوع (الجنس) *'),
                            items: const [
                              DropdownMenuItem(value: 'ذكر', child: Text('ذكر')),
                              DropdownMenuItem(value: 'أنثى', child: Text('أنثى')),
                            ],
                            onChanged: (val) => setModalState(() => gender = val!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: bloodGroup,
                            decoration: const InputDecoration(labelText: 'فصيلة الدم'),
                            items: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-', 'غير محدد'].map((bg) {
                              return DropdownMenuItem(value: bg, child: Text(bg));
                            }).toList(),
                            onChanged: (val) => setModalState(() => bloodGroup = val!),
                          ),
                        ),
                      ],
                    ),
                    if (gender == 'أنثى') ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: femaleStatus,
                        decoration: const InputDecoration(labelText: 'الحالة الفسيولوجية للأنثى (تؤثر على الهرمونات)'),
                        items: const [
                          DropdownMenuItem(value: 'طبيعي', child: Text('طبيعي')),
                          DropdownMenuItem(value: 'حامل', child: Text('حامل')),
                          DropdownMenuItem(value: 'مرضع', child: Text('مرضع')),
                        ],
                        onChanged: (val) => setModalState(() => femaleStatus = val!),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Section 3: Emergency Contact & Insurance Entity
                    const Text('3. هاتف الطوارئ والجهة/التعاقد:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: emergencyPhoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(labelText: 'هاتف الطوارئ / القرابة'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: contractEntity,
                            decoration: const InputDecoration(labelText: 'الجهة / التعاقد'),
                            items: const [
                              DropdownMenuItem(value: 'نقدي (خاص)', child: Text('نقدي (خاص)')),
                              DropdownMenuItem(value: 'تأمين صحي', child: Text('تأمين صحي')),
                              DropdownMenuItem(value: 'شركة تعاقد خاص', child: Text('شركة تعاقد خاص')),
                              DropdownMenuItem(value: 'نقابة المهندسين/الأطباء', child: Text('نقابة المهندسين/الأطباء')),
                            ],
                            onChanged: (val) => setModalState(() => contractEntity = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Section 4: Chronic Conditions & Allergies Tags
                    const Text('4. الأمراض المزمنة والحساسية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: chronicList.map((ch) {
                        final isSel = selectedChronic.contains(ch);
                        return FilterChip(
                          selected: isSel,
                          label: Text(ch),
                          onSelected: (val) {
                            setModalState(() {
                              if (val) {
                                selectedChronic.add(ch);
                              } else {
                                selectedChronic.remove(ch);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: allergiesCtrl,
                      decoration: const InputDecoration(labelText: 'الحساسية الدوائية والغذائية (مثال: بنسلين)'),
                    ),
                    const SizedBox(height: 20),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('إلغاء')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: () async {
                            if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
                            final nowStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

                            final patientData = {
                              'name': nameCtrl.text.trim(),
                              'phone': phoneCtrl.text.trim(),
                              'national_id': nationalIdCtrl.text.trim(),
                              'age': ageYears,
                              'gender': gender,
                              'dob': DateFormat('yyyy-MM-dd').format(dob),
                              'blood_group': bloodGroup,
                              'female_status': femaleStatus,
                              'emergency_phone': emergencyPhoneCtrl.text.trim(),
                              'contract_entity': contractEntity,
                              'chronic_diseases': selectedChronic.join('، '),
                              'allergies': allergiesCtrl.text.trim().isEmpty ? 'لا توجد' : allergiesCtrl.text.trim(),
                              'medical_history': 'تسجيل أولي بدون ملاحظات سريرية',
                              'created_at': nowStr,
                            };

                            final result = await _viewModel.clinicCubit.addPatient(patientData);
                            result.fold(
                              (_) {},
                              (newId) {
                                if (mounted) {
                                  setState(() {
                                    _selectedPatient = {
                                      'id': newId,
                                      ...patientData,
                                    };
                                  });
                                  _viewModel.clinicCubit.fetchPatientRecord(newId);
                                }
                              },
                            );

                            if (dialogCtx.mounted) {
                              Navigator.of(dialogCtx).pop();
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم حفظ المريض والملف الطبي بنجاح!'), backgroundColor: AppColors.success),
                              );
                            }
                          },
                          child: const Text('حفظ المريض والملف الطبي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddLabResultDialog(BuildContext context, int patientId) {
    final testNameCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'mg/dL');
    final refRangeCtrl = TextEditingController(text: '70 - 110');
    String status = 'طبيعي';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('إضافة نتيجة فحص معملي'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: testNameCtrl, decoration: const InputDecoration(labelText: 'اسم الفحص (مثال: HbA1c / السكر التراكمي)')),
              const SizedBox(height: 10),
              TextField(controller: valueCtrl, decoration: const InputDecoration(labelText: 'القيمة المقاسة')),
              const SizedBox(height: 10),
              TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'وحدة القياس')),
              const SizedBox(height: 10),
              TextField(controller: refRangeCtrl, decoration: const InputDecoration(labelText: 'المدى المرجعي (Reference Range)')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'حالة النتيجة'),
                items: const [
                  DropdownMenuItem(value: 'طبيعي', child: Text('طبيعي (Normal)')),
                  DropdownMenuItem(value: 'مرتفع', child: Text('مرتفع (High)')),
                  DropdownMenuItem(value: 'منخفض', child: Text('منخفض (Low)')),
                ],
                onChanged: (val) => setModalState(() => status = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                if (testNameCtrl.text.isEmpty || valueCtrl.text.isEmpty) return;
                final nowStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

                await _viewModel.clinicCubit.addLabResult({
                  'patient_id': patientId,
                  'test_name': testNameCtrl.text.trim(),
                  'test_date': nowStr,
                  'measured_value': valueCtrl.text.trim(),
                  'unit': unitCtrl.text.trim(),
                  'reference_range': refRangeCtrl.text.trim(),
                  'status': status,
                });

                if (dialogCtx.mounted) {
                  Navigator.of(dialogCtx).pop();
                }
              },
              child: const Text('حفظ النتيجة', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAttachmentDialog(BuildContext context, int patientId) {
    final fileNameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('إرفاق مستند أو روشتة خارية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: fileNameCtrl, decoration: const InputDecoration(labelText: 'اسم المستند (مثال: أشعة سينية / روشتة خارية)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              if (fileNameCtrl.text.isEmpty) return;
              final nowStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

              await _viewModel.clinicCubit.addPatientAttachment({
                'patient_id': patientId,
                'file_name': fileNameCtrl.text.trim(),
                'file_type': 'IMAGE',
                'file_path': 'sample_path.png',
                'created_at': nowStr,
              });

              if (dialogCtx.mounted) {
                Navigator.of(dialogCtx).pop();
              }
            },
            child: const Text('إرفاق', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
