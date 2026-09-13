import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/enums/appointment_enums.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/security/session_manager.dart';
import '../../../../core/security/shift_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../shared/cubit/block_builder_widget.dart';
import '../../../shift/view/shift_screen.dart';
import '../../data/cubit/clinic_cubit.dart';
import '../clinic_view_model.dart';

class ConsultationScreen extends StatefulWidget {
  const ConsultationScreen({super.key});

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  late final ClinicViewModel _viewModel;
  int? _selectedPatientId;

  bool get _isPatientSelected => _selectedPatientId != null;

  @override
  void initState() {
    super.initState();
    _viewModel = sl<ClinicViewModel>()..updateRefresh(() {
      if (mounted) setState(() {});
    });
    _viewModel.clinicCubit.fetchPatients();
    _viewModel.clinicCubit.fetchAppointments();
    _viewModel.clinicCubit.fetchWaitingQueue();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _onSavePrescription() {
    final hasShift = ShiftGuard.checkShiftOrWarn(
      context,
      onNavigateToShift: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShiftScreen()));
      },
    );

    if (!hasShift) return;

    if (!_isPatientSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار المريض أولاً لكتابة الروشتة'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_viewModel.diagnosisController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة التشخيص الطبي'), backgroundColor: AppColors.error),
      );
      return;
    }

    final doctor = SessionManager.instance.currentUser;
    final doctorId = doctor?['id'] ?? 1;
    final nowStr = DateTime.now().toIso8601String().substring(0, 10);

    _viewModel.clinicCubit.addPrescription(
      prescription: {
        'appointment_id': null,
        'patient_id': _selectedPatientId!,
        'doctor_id': doctorId,
        'diagnosis': _viewModel.diagnosisController.text.trim(),
        'notes': _viewModel.notesController.text.trim(),
        'created_at': nowStr,
      },
      items: _viewModel.prescriptionItems,
    ).then((res) {
      res.fold(
        (err) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message))),
        (_) {
          // Complete appointment status in queue
          _viewModel.clinicCubit.fetchWaitingQueue().then((_) {
            final queue = _viewModel.clinicCubit.waitingQueue;
            final currentAppt = queue.firstWhere(
              (q) => q['patient_id'] == _selectedPatientId && AppointmentStatus.fromString(q['status']).isInProgress,
              orElse: () => {},
            );
            if (currentAppt.isNotEmpty) {
              _viewModel.clinicCubit.updateAppointmentStatus(
                currentAppt['id'] as int,
                AppointmentStatus.completed.dbValue,
              );
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حفظ الروشتة الإلكترونية وإنهاء الكشف بنجاح!'), backgroundColor: AppColors.success),
          );
          _viewModel.clearPrescriptionForm();
          setState(() => _selectedPatientId = null);
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlockBuilderWidget<ClinicCubit, ClinicApiType>(
        types: const [
          ClinicApiType.getPatients,
          ClinicApiType.getWaitingRoom,
          ClinicApiType.getPatientRecord,
        ],
        loading: (_) => const Center(child: CircularProgressIndicator()),
        body: (_) => ResponsiveLayout(
          mobile: _buildMobileLayout(),
          tablet: _buildTabletLayout(),
          desktop: _buildDesktopLayout(),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. Desktop Layout (>= 1024px) — Split View with Patient Slate & Prescription Form
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isMobile: false),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Pane: Active Queue & Patient Demographics (35%)
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      _buildPatientSelectorCard(),
                      const SizedBox(height: 16),
                      Expanded(child: _buildPatientDemographicsCard()),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                // Right Pane: Diagnosis & Smart E-Prescription Form (65%)
                Expanded(
                  flex: 6,
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: SingleChildScrollView(
                        child: _buildPrescriptionFormContent(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. Tablet Layout (600px - 1023px) — Dual Column Layout
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTabletLayout() {
    return Padding(
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isMobile: false),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildPatientSelectorCard(),
                        const SizedBox(height: 14),
                        _buildPatientDemographicsCard(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 7,
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: SingleChildScrollView(
                        child: _buildPrescriptionFormContent(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. Mobile Layout (< 600px) — Single Column Stack
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isMobile: true),
          const SizedBox(height: 14),
          _buildPatientSelectorCard(),
          const SizedBox(height: 14),
          _buildPatientDemographicsCard(),
          const SizedBox(height: 14),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildPrescriptionFormContent(),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Shared Components
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader({required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'شاشة الكشف والروشتة الإلكترونية (Consultation)',
          style: TextStyle(
            fontSize: isMobile ? 18 : 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'منطقة عمل الطبيب: الفحص السريري، كتابة التشخيص والروشتة الذكية',
          style: TextStyle(
            fontSize: isMobile ? 12 : 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPatientSelectorCard() {
    final patients = _viewModel.clinicCubit.patients;
    final queue = _viewModel.clinicCubit.waitingQueue;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person_search_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('اختيار المريض للكشف الحالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Waiting Queue Quick Selector Chip Bar
            if (queue.isNotEmpty) ...[
              const Text('مرضى في الانتظار اليوم:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: queue.map((q) {
                    final int pId = q['patient_id'] as int;
                    final bool isSel = _selectedPatientId == pId;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6.0),
                      child: ChoiceChip(
                        selected: isSel,
                        selectedColor: AppColors.primaryLight,
                        label: Text(q['patient_name'] ?? 'مريض', style: TextStyle(fontSize: 12, color: isSel ? AppColors.primary : Colors.black87)),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _selectedPatientId = pId);
                            _viewModel.clinicCubit.fetchPatientRecord(pId);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],

            DropdownButtonFormField<int>(
              initialValue: _selectedPatientId,
              hint: const Text('اختر المريض من القائمة...'),
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              items: patients.map((p) {
                return DropdownMenuItem<int>(
                  value: p['id'] as int,
                  child: Text('${p['name']} (${p['phone']})', overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() => _selectedPatientId = val);
                _viewModel.clinicCubit.fetchPatientRecord(val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientDemographicsCard() {
    if (!_isPatientSelected) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_shared_outlined, size: 48, color: AppColors.textLight),
                SizedBox(height: 12),
                Text('قم باختيار مريض لعرض بياناته السريرية والتنبيهات الطبية', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    final pList = _viewModel.clinicCubit.patients.where((p) => p['id'] == _selectedPatientId).toList();
    if (pList.isEmpty) return const SizedBox.shrink();
    final p = pList.first;

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
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary,
                  child: Text((p['name'] as String? ?? 'P')[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('السن: ${p['age'] ?? 'غير محدد'} سنة | فصيلة الدم: ${p['blood_group'] ?? 'غير محدد'}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // High Risk Clinical Banner
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text('الحساسية: $allergies', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.medical_services_outlined, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text('الأمراض المزمنة: $chronic', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionFormContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('التشخيص الطبي والروشتة الإلكترونية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(
          controller: _viewModel.diagnosisController,
          decoration: const InputDecoration(
            labelText: 'التشخيص الطبي (Diagnosis) *',
            prefixIcon: Icon(Icons.medical_information_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _viewModel.notesController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'تعليمات وإرشادات للمريض',
            prefixIcon: Icon(Icons.format_list_bulleted),
          ),
        ),
        const SizedBox(height: 24),
        const Text('إضافة الأدوية والعلاج (Rx):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),

        // Drug Entry Form Grid
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _viewModel.medNameController,
                decoration: const InputDecoration(labelText: 'اسم الدواء (مثال: Augmentin 1g)'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _viewModel.medDosageController,
                decoration: const InputDecoration(labelText: 'الجرعة (قرص/قرصين)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _viewModel.medFreqController,
                decoration: const InputDecoration(labelText: 'التكرار (كل 12 ساعة)'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _viewModel.medDurationController,
                decoration: const InputDecoration(labelText: 'المدة (لمدة أسبوع)'),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
              onPressed: _viewModel.addPrescriptionItem,
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              label: const Text('إضافة', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Added prescription items list
        if (_viewModel.prescriptionItems.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _viewModel.prescriptionItems.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _viewModel.prescriptionItems[index];
                return ListTile(
                  title: Text(item['medicine_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('الجرعة: ${item['dosage']} | التكرار: ${item['frequency']} | المدة: ${item['duration']}', style: const TextStyle(fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error),
                    onPressed: () => _viewModel.removePrescriptionItem(index),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Submit Button with Loading Indicator State
        BlockBuilderWidget<ClinicCubit, ClinicApiType>(
          types: const [ClinicApiType.addPrescription],
          body: (_) => _buildSubmitPrescriptionButton(),
          error: (_) => _buildSubmitPrescriptionButton(),
          loading: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      ],
    );
  }

  Widget _buildSubmitPrescriptionButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: _onSavePrescription,
        icon: const Icon(Icons.print, color: Colors.white),
        label: const Text(
          'حفظ وطباعة الروشتة الإلكترونية وإنهاء الكشف',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
