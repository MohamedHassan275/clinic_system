import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
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

  @override
  void initState() {
    super.initState();
    _viewModel = sl<ClinicViewModel>()..updateRefresh(() {
      if (mounted) setState(() {});
    });
    _viewModel.clinicCubit.fetchPatients();
    _viewModel.clinicCubit.fetchAppointments();
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

    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار المريض أولاً'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_viewModel.diagnosisController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة التشخيص الطبي'), backgroundColor: AppColors.error),
      );
      return;
    }

    final doctor = SessionManager.instance.currentUser;
    final nowStr = DateTime.now().toIso8601String().substring(0, 10);

    _viewModel.clinicCubit.addPrescription(
      prescription: {
        'appointment_id': 1,
        'patient_id': _selectedPatientId!,
        'doctor_id': doctor!['id'],
        'diagnosis': _viewModel.diagnosisController.text,
        'notes': _viewModel.notesController.text,
        'created_at': nowStr,
      },
      items: _viewModel.prescriptionItems,
    ).then((res) {
      res.fold(
        (err) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message))),
        (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حفظ الروشتة الإلكترونية وطباعتها بنجاح!'), backgroundColor: AppColors.success),
          );
          _viewModel.clearPrescriptionForm();
        },
      );
    });
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
            const Text('شاشة الكشف والروشتة الإلكترونية', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('منطقة عمل الطبيب: التشخيص وسجل العلاج وطباعة الروشتة الذكية', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Pane: Patient Selection & Summary (35%)
                  Expanded(
                    flex: 4,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('اختيار المريض للكشف الحالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 16),
                            BlockBuilderWidget<ClinicCubit, ClinicApiType>(
                              types: const [ClinicApiType.getPatients],
                              body: (_) {
                                final patients = _viewModel.clinicCubit.patients;
                                return DropdownButtonFormField<int>(
                                  initialValue: _selectedPatientId,
                                  hint: const Text('اختر المريض...'),
                                  isExpanded: true,
                                  items: patients.map((p) {
                                    return DropdownMenuItem<int>(
                                      value: p['id'] as int,
                                      child: Text('${p['name']} (${p['phone']})'),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setState(() => _selectedPatientId = val),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 12),
                            const Text('معلومات المريض المختار:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(
                              _selectedPatientId == null
                                  ? 'اختر مريضاً لبدء كتابة التشخيص والروشتة'
                                  : 'تم تحديد المريض بنجاح لكتابة التشخيص العلاجي',
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Right Pane: Diagnosis & Smart Prescription Form (65%)
                  Expanded(
                    flex: 6,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('التشخيص الطبي والروشتة الإلكترونية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _viewModel.diagnosisController,
                                decoration: const InputDecoration(
                                  labelText: 'التشخيص الطبي (Diagnosis)',
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
                                    onPressed: _viewModel.addPrescriptionItem,
                                    icon: const Icon(Icons.add, color: Colors.white),
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
                                        title: Text(item['medicine_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        subtitle: Text('الجرعة: ${item['dosage']} | التكرار: ${item['frequency']} | المدة: ${item['duration']}'),
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
                              // POST Pattern: BlockBuilderWidget wraps ONLY the submit button
                              BlockBuilderWidget<ClinicCubit, ClinicApiType>(
                                types: const [ClinicApiType.addPrescription],
                                body: (_) => _buildSubmitPrescriptionButton(),
                                error: (_) => _buildSubmitPrescriptionButton(),
                                loading: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitPrescriptionButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
        onPressed: _onSavePrescription,
        icon: const Icon(Icons.print, color: Colors.white),
        label: const Text(
          'حفظ وطباعة الروشتة الإلكترونية',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
