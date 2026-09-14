import 'package:flutter/material.dart';
import '../../../../core/common/widgets/app_dialog.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/security/shift_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../shared/cubit/block_builder_widget.dart';
import '../../data/cubit/clinic_cubit.dart';
import '../clinic_view_model.dart';
import '../widgets/patient/patient_attachments_tab_widget.dart';
import '../widgets/patient/patient_history_tab_widget.dart';
import '../widgets/patient/patient_lab_results_tab_widget.dart';
import '../widgets/patient/patient_prescriptions_tab_widget.dart';
import '../widgets/patient/patient_profile_tab_widget.dart';
import '../widgets/patient/patient_vitals_tab_widget.dart';
import 'patient_detail_hub_screen.dart';
import 'patient_registration_screen.dart';

class EMRScreen extends StatefulWidget {
  const EMRScreen({super.key});

  @override
  State<EMRScreen> createState() => _EMRScreenState();
}

class _EMRScreenState extends State<EMRScreen> with SingleTickerProviderStateMixin {
  late final ClinicViewModel _viewModel;
  Map<String, dynamic>? _selectedPatient;
  late TabController _tabController;

  static const List<String> _contractFilters = [
    'الكل',
    'نقدي (خاص)',
    'تأمين صحي',
    'شركة تعاقد خاص',
    'نقابة المهندسين/الأطباء',
  ];
  String _selectedContractFilter = 'الكل';

  bool get _hasSelectedPatient => _selectedPatient != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
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

  void _onSearchOrFilterChanged() {
    final search = _viewModel.patientSearchController.text.trim();
    if (_selectedContractFilter == 'الكل') {
      _viewModel.clinicCubit.fetchPatients(query: search.isEmpty ? null : search);
      return;
    }
    final combinedQuery = search.isEmpty ? _selectedContractFilter : search;
    _viewModel.clinicCubit.fetchPatients(query: combinedQuery);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ResponsiveLayout(
        mobile: _buildMobileLayout(context),
        tablet: _buildDesktopMasterDetailLayout(context),
        desktop: _buildDesktopMasterDetailLayout(context),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. Mobile View (< 600px) — Standalone Patient Master List
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الملف الطبي للمرضى (EMR)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('السجل الطبي الشامل ونتائج الفحوصات والروشتات', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
                if (!ShiftGuard.checkShiftOrWarn(context)) return;
                _showPatientFormDialog(context);
              },
              icon: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 20),
              label: const Text('تسجيل مريض جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 14),
          _buildSearchAndFilterRow(),
          const SizedBox(height: 14),
          Expanded(
            child: BlockBuilderWidget<ClinicCubit, ClinicApiType>(
              types: const [ClinicApiType.getPatients, ClinicApiType.addPatient],
              loading: (_) => const Center(child: CircularProgressIndicator()),
              body: (_) => _buildPatientsList(isMobile: true),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. Desktop & Tablet Layout (>= 600px) — Split Master-Detail Workspace
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopMasterDetailLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الملف الطبي للمرضى (EMR)', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('نظام إدارة سجلات المرضى والملفات السريرية المتكامل', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (!ShiftGuard.checkShiftOrWarn(context)) return;
                  _showPatientFormDialog(context);
                },
                icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                label: const Text('تسجيل مريض جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSearchAndFilterRow(),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                // Patients Master List (Left Column 35%)
                Expanded(
                  flex: 3,
                  child: BlockBuilderWidget<ClinicCubit, ClinicApiType>(
                    types: const [ClinicApiType.getPatients, ClinicApiType.addPatient],
                    loading: (_) => const Center(child: CircularProgressIndicator()),
                    body: (_) => _buildPatientsList(isMobile: false),
                  ),
                ),
                const SizedBox(width: 16),

                // Patient Detailed Clinical Workspace (Right Column 65% with 6 Tabs)
                Expanded(
                  flex: 6,
                  child: !_hasSelectedPatient
                      ? Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_shared_outlined, size: 64, color: AppColors.textLight),
                                SizedBox(height: 16),
                                Text(
                                  'اختر مريضاً من القائمة لعرض ملفه الطبي الشامل وتنبيهاته السريرية',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                                ),
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
    );
  }

  Widget _buildSearchAndFilterRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _viewModel.patientSearchController,
            decoration: InputDecoration(
              hintText: 'البحث باسم المريض، رقم الهاتف، أو الرقم القومي...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (_) => _onSearchOrFilterChanged(),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedContractFilter,
              icon: const Icon(Icons.filter_alt_outlined, color: AppColors.primary),
              onChanged: (val) {
                if (val == null) return;
                setState(() => _selectedContractFilter = val);
                _onSearchOrFilterChanged();
              },
              items: _contractFilters.map((f) {
                return DropdownMenuItem<String>(
                  value: f,
                  child: Text(f, style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPatientsList({required bool isMobile}) {
    final list = _viewModel.clinicCubit.patients;
    if (list.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text('لا يوجد مرضى مطابقون مع ناتج البحث')),
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
            subtitle: Text('الهاتف: ${p['phone'] ?? 'بدون'} | الجهة: ${p['contract_entity'] ?? 'نقدي'}', style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
            onTap: () {
              setState(() => _selectedPatient = p);
              _viewModel.clinicCubit.fetchPatientRecord(p['id'] as int);

              // On Mobile: Open Mobile PatientDetailHubScreen
              if (isMobile) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PatientDetailHubScreen(patient: p),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildPatientClinicalDashboard() {
    final p = _selectedPatient!;
    final record = _viewModel.clinicCubit.selectedPatientRecord;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Actions Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    (p['name'] as String? ?? 'P')[0],
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['name'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        'السن: ${p['age'] ?? 'غير محدد'} سنة | الهاتف: ${p['phone'] ?? 'غير مسجل'} | الجهة: ${p['contract_entity'] ?? 'نقدي'}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                  tooltip: 'تعديل بيانات المريض',
                  onPressed: () {
                    if (!ShiftGuard.checkShiftOrWarn(context)) return;
                    PatientRegistrationScreen.show(context, initialPatient: p);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  tooltip: 'حذف سجل المريض',
                  onPressed: () => _confirmDeletePatient(context, p),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 6 Internal Navigation Tabs
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(icon: Icon(Icons.person_outline_rounded), text: 'البيانات الشخصية'),
              Tab(icon: Icon(Icons.monitor_heart_outlined), text: 'العلامات الحيوية'),
              Tab(icon: Icon(Icons.science_outlined), text: 'التحاليل والفحوصات'),
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'الروشتات الطبية'),
              Tab(icon: Icon(Icons.folder_open_outlined), text: 'المرفقات والأشعة'),
              Tab(icon: Icon(Icons.history_toggle_off_rounded), text: 'السجل والزيارات'),
            ],
          ),
          const Divider(height: 1),

          // 6 Tab Content Views
          Expanded(
            child: BlockBuilderWidget<ClinicCubit, ClinicApiType>(
              types: const [ClinicApiType.getPatientRecord],
              loading: (_) => const Center(child: CircularProgressIndicator()),
              body: (_) {
                return TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Profile
                    PatientProfileTabWidget(
                      patient: p,
                      onEditPressed: () {
                        if (!ShiftGuard.checkShiftOrWarn(context)) return;
                        PatientRegistrationScreen.show(context, initialPatient: p);
                      },
                    ),
                    // Tab 2: Vitals
                    PatientVitalsTabWidget(
                      patientRecord: record ?? p,
                    ),
                    // Tab 3: Lab Results
                    PatientLabResultsTabWidget(
                      selectedPatientRecord: record,
                      patientId: p['id'] as int,
                      cubit: _viewModel.clinicCubit,
                    ),
                    // Tab 4: Prescriptions
                    PatientPrescriptionsTabWidget(
                      selectedPatientRecord: record,
                      patient: p,
                    ),
                    // Tab 5: Attachments
                    PatientAttachmentsTabWidget(
                      selectedPatientRecord: record,
                      patientId: p['id'] as int,
                      cubit: _viewModel.clinicCubit,
                    ),
                    // Tab 6: History
                    PatientHistoryTabWidget(
                      selectedPatientRecord: record,
                      patient: p,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePatient(BuildContext context, Map<String, dynamic> patient) async {
    if (!ShiftGuard.checkShiftOrWarn(context)) return;
    final int patientId = patient['id'] as int;
    final String patientName = patient['name'] ?? '';

    final bool confirmed = await showAppConfirmDialog(
      context: context,
      title: 'حذف سجل المريض',
      message: 'هل أنت تأكد من رغبتك في حذف سجل المريض "$patientName"؟\nسيتم إزالة البيانات الخاصة بهذا المريض بشكل دائم.',
      confirmText: 'حذف المريض',
      confirmColor: AppColors.error,
      icon: Icons.warning_amber_rounded,
    );

    if (!confirmed) return;

    final res = await _viewModel.clinicCubit.deletePatient(patientId);
    res.fold(
      (failure) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ أثناء الحذف: ${failure.message}'), backgroundColor: AppColors.error),
          );
        }
      },
      (_) {
        if (mounted) {
          setState(() => _selectedPatient = null);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف سجل المريض بنجاح'), backgroundColor: AppColors.success),
          );
        }
      },
    );
  }

  void _showPatientFormDialog(BuildContext context, {Map<String, dynamic>? initialPatient}) {
    PatientRegistrationScreen.show(context, initialPatient: initialPatient);
  }
}
