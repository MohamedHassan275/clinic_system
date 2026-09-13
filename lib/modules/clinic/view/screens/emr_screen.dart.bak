import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/common/widgets/app_dialog.dart';
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
    final media = MediaQuery.of(context);
    final bool isMobile = media.size.width < 768;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 14.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Responsive Header
            if (isMobile) ...[
              if (_selectedPatient != null)
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => setState(() => _selectedPatient = null),
                      tooltip: 'الرجوع لقائمة المرضى',
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _selectedPatient!['name'] ?? 'تفاصيل المريض',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الملف الطبي للمرضى (EMR)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('السجل الطبي الشامل ونتائج الفحوصات والروشتات', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          if (ShiftGuard.checkShiftOrWarn(context)) {
                            _showAddPatientDialog(context);
                          }
                        },
                        icon: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 20),
                        label: const Text('تسجيل مريض جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
            ] else ...[
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
            ],
            const SizedBox(height: 16),

            // Search Bar (Shown if patient not selected on mobile or on desktop)
            if (!isMobile || _selectedPatient == null) ...[
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
            ],

            // Main Workspace View (Responsive Mobile vs Desktop)
            Expanded(
              child: isMobile
                  ? (_selectedPatient == null
                      ? BlockBuilderWidget<ClinicCubit, ClinicApiType>(
                          types: const [ClinicApiType.getPatients],
                          body: (_) => _buildPatientsList(),
                          loading: (_) => const Center(child: CircularProgressIndicator()),
                        )
                      : _buildPatientClinicalDashboard())
                  : Row(
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
          final bool isSelected = _selectedPatient != null && _selectedPatient!['id'] == p['id'];

          return ListTile(
            selected: isSelected,
            selectedTileColor: AppColors.primaryLight.withValues(alpha: 0.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(
              backgroundColor: isSelected ? AppColors.primary : Colors.grey[200],
              child: Text(
                '#${p['id']}',
                style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            title: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('الهاتف: ${p['phone'] ?? 'بدون'} | فصيلة الدم: ${p['blood_group'] ?? 'غير محدد'}', style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
            onTap: () {
              setState(() => _selectedPatient = p);
              _viewModel.clinicCubit.fetchPatientRecord(p['id'] as int);
            },
          );
        },
      ),
    );
  }

  Widget _buildPatientClinicalDashboard() {
    final p = _selectedPatient!;

    final String allergies = p['allergies'] ?? 'لا توجد';
    final String chronic = p['chronic_diseases'] ?? 'لا توجد';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Critical Header Bar with Clinical Demographics
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    (p['name'] as String? ?? 'P')[0],
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        'السن: ${p['age'] ?? 'غير محدد'} سنة | الجنس: ${p['gender'] ?? 'ذكر'} | فصيلة الدم: ${p['blood_group'] ?? 'غير محدد'} | الجهة: ${p['contract_entity'] ?? 'نقدي'}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. High-Risk Clinical Banner (Allergies & Chronic Conditions)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('الحساسية:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 12)),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(6)),
                        child: Text(allergies, style: TextStyle(color: Colors.red[900], fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('الأمراض المزمنة:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 12)),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(6)),
                        child: Text(chronic, style: TextStyle(color: Colors.amber[900], fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 3. Tabbed View
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(icon: Icon(Icons.analytics_outlined), text: 'التحاليل والفحوصات'),
                Tab(icon: Icon(Icons.receipt_long), text: 'الروشتات والمرفقات'),
                Tab(icon: Icon(Icons.medication_liquid), text: 'التاريخ الدوائي والملاحظات'),
              ],
            ),
            const SizedBox(height: 12),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  BlockBuilderWidget<ClinicCubit, ClinicApiType>(
                    types: const [ClinicApiType.getPatientRecord],
                    body: (_) => _buildLabResultsTab(),
                    loading: (_) => const Center(child: CircularProgressIndicator()),
                  ),
                  BlockBuilderWidget<ClinicCubit, ClinicApiType>(
                    types: const [ClinicApiType.getPatientRecord],
                    body: (_) => _buildAttachmentsTab(p['id'] as int),
                    loading: (_) => const Center(child: CircularProgressIndicator()),
                  ),
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
            const Icon(Icons.science_outlined, size: 44, color: AppColors.textLight),
            const SizedBox(height: 8),
            const Text('لا توجد نتائج فحوصات معملية سابقة مسجلة للمريض', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _showAddLabResultDialog(context, _selectedPatient!['id'] as int),
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
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
          title: Text(lab['test_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text('التاريخ: ${lab['test_date']} | القيمة: ${lab['measured_value']} ${lab['unit']} | المدى: ${lab['reference_range']}', style: const TextStyle(fontSize: 12)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: flagColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(status, style: TextStyle(color: flagColor, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentsTab(int patientId) {
    final record = _viewModel.clinicCubit.selectedPatientRecord;
    final rxList = record != null ? (record['prescriptions'] as List? ?? []) : [];
    final attachList = record != null ? (record['attachments'] as List? ?? []) : [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('1. الروشتات الصادرة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: () => _showAddAttachmentDialog(context, patientId),
                icon: const Icon(Icons.upload_file, size: 16, color: Colors.white),
                label: const Text('إرفاق مستند خارجي', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (rxList.isEmpty)
            const Text('لا توجد روشتات سابقة صادرة لهذا المريض', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
          else
            Column(
              children: rxList.map((rx) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.medical_information, color: AppColors.primary),
                    title: Text('روشتة بتاريخ: ${rx['created_at']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('التشخيص: ${rx['diagnosis'] ?? 'غير محدد'} | الطبيب: ${rx['doctor_name'] ?? 'د. العيادة'}', style: const TextStyle(fontSize: 12)),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          const Text('2. المرفقات والأشعّات الخارجية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
          const SizedBox(height: 8),
          if (attachList.isEmpty)
            const Text('لا توجد مرفقات خارجية مسجلة', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
          else
            Column(
              children: attachList.map((at) {
                return ListTile(
                  leading: const Icon(Icons.attach_file, color: AppColors.secondary),
                  title: Text(at['file_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('التاريخ: ${at['created_at']} | النوع: ${at['file_type']}', style: const TextStyle(fontSize: 12)),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildMedicationsAndNotesTab(Map<String, dynamic> p) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ملاحظات وسجل العيادة التاريخي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              p['medical_history'] ?? 'تسجيل أولي بدون ملاحظات سريرية سابقة.',
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
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

          return AppDialog(
            title: 'إضافة مريض جديد والتسجيل السريري',
            subtitle: 'أدخل البيانات الشخصية والطبية الهامة لتأسيس الملف السريري للمريض',
            icon: Icons.person_add_alt_1_rounded,
            iconColor: AppColors.primary,
            maxWidth: 580,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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

                // Section 2: Clinical Demographics
                const Text('2. البيانات السريرية وفصيلة الدم:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
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
                    decoration: const InputDecoration(labelText: 'الحالة الفسيولوجية للأنثى'),
                    items: const [
                      DropdownMenuItem(value: 'طبيعي', child: Text('طبيعي')),
                      DropdownMenuItem(value: 'حامل', child: Text('حامل')),
                      DropdownMenuItem(value: 'مرضع', child: Text('مرضع')),
                    ],
                    onChanged: (val) => setModalState(() => femaleStatus = val!),
                  ),
                ],
                const SizedBox(height: 16),

                // Section 3: Emergency Contact & Insurance
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
                  runSpacing: 6,
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
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary))),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        builder: (ctx, setModalState) => AppDialog(
          title: 'إضافة نتيجة فحص معملي',
          subtitle: 'تسجيل نتائج التحاليل والفحوصات في سجل المريض',
          icon: Icons.science_outlined,
          iconColor: AppColors.primary,
          maxWidth: 480,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
            TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary))),
            const SizedBox(width: 8),
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
              child: const Text('حفظ النتيجة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      builder: (dialogCtx) => AppDialog(
        title: 'إرفاق مستند أو روشتة خارجية',
        subtitle: 'أدخل اسم المستند لحفظه في الملف السريري للمريض',
        icon: Icons.upload_file,
        iconColor: AppColors.secondary,
        maxWidth: 440,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: fileNameCtrl,
              decoration: const InputDecoration(labelText: 'اسم المستند (مثال: أشعة سينية / روشتة خارجية)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary))),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
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
            child: const Text('إرفاق', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
