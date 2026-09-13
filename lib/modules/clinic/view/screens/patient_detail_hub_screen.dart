import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/common/widgets/app_dialog.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/security/shift_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../shared/cubit/block_builder_widget.dart';
import '../../data/cubit/clinic_cubit.dart';
import '../widgets/patient/patient_attachments_tab_widget.dart';
import '../widgets/patient/patient_history_tab_widget.dart';
import '../widgets/patient/patient_lab_results_tab_widget.dart';
import '../widgets/patient/patient_prescriptions_tab_widget.dart';
import '../widgets/patient/patient_profile_tab_widget.dart';
import '../widgets/patient/patient_vitals_tab_widget.dart';

import 'patient_registration_screen.dart';

class PatientDetailHubScreen extends StatefulWidget {
  final Map<String, dynamic> patient;

  const PatientDetailHubScreen({
    super.key,
    required this.patient,
  });

  @override
  State<PatientDetailHubScreen> createState() => _PatientDetailHubScreenState();
}

class _PatientDetailHubScreenState extends State<PatientDetailHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final ClinicCubit _clinicCubit;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _clinicCubit = sl<ClinicCubit>();
    _clinicCubit.fetchPatientRecord(widget.patient['id'] as int);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    final int patientId = p['id'] as int;

    return BlocProvider.value(
      value: _clinicCubit,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 1,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'الرجوع لقائمة المرضى',
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p['name'] ?? 'ملف المريض',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'الهاتف: ${p['phone'] ?? ''} | الجهة: ${p['contract_entity'] ?? 'نقدي'}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                tooltip: 'تعديل بيانات المريض',
                onPressed: () {
                  if (!ShiftGuard.checkShiftOrWarn(context)) return;
                  _showEditPatientModal(context, p);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                tooltip: 'حذف سجل المريض',
                onPressed: () => _confirmDeletePatient(context, p),
              ),
            ],
            bottom: TabBar(
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
          ),
          body: BlockBuilderWidget<ClinicCubit, ClinicApiType>(
            types: const [ClinicApiType.getPatientRecord],
            loading: (_) => const Center(child: CircularProgressIndicator()),
            body: (_) {
              final record = _clinicCubit.selectedPatientRecord;
              return TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Profile
                  PatientProfileTabWidget(
                    patient: p,
                    onEditPressed: () {
                      if (!ShiftGuard.checkShiftOrWarn(context)) return;
                      _showEditPatientModal(context, p);
                    },
                  ),
                  // Tab 2: Vitals
                  PatientVitalsTabWidget(
                    patientRecord: record ?? p,
                  ),
                  // Tab 3: Lab Results
                  PatientLabResultsTabWidget(
                    selectedPatientRecord: record,
                    patientId: patientId,
                    cubit: _clinicCubit,
                  ),
                  // Tab 4: Prescriptions
                  PatientPrescriptionsTabWidget(
                    selectedPatientRecord: record,
                    patient: p,
                  ),
                  // Tab 5: Attachments
                  PatientAttachmentsTabWidget(
                    selectedPatientRecord: record,
                    patientId: patientId,
                    cubit: _clinicCubit,
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

    final res = await _clinicCubit.deletePatient(patientId);
    res.fold(
      (failure) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ أثناء الحذف: ${failure.message}'), backgroundColor: AppColors.error),
          );
        }
      },
      (_) {
        if (context.mounted) {
          Navigator.of(context).pop(); // Back to master list
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف سجل المريض بنجاح'), backgroundColor: AppColors.success),
          );
        }
      },
    );
  }

  void _showEditPatientModal(BuildContext context, Map<String, dynamic> initialPatient) {
    PatientRegistrationScreen.show(context, initialPatient: initialPatient);
  }
}
