import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/common/widgets/app_dialog.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/enums/appointment_enums.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/security/session_manager.dart';
import '../../../../core/security/shift_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../shared/cubit/block_builder_widget.dart';
import '../../../shift/view/shift_screen.dart';
import '../../data/cubit/clinic_cubit.dart';
import '../clinic_view_model.dart';
import 'patient_detail_hub_screen.dart';

class ConsultationScreen extends StatefulWidget {
  final int? patientId;
  final int? appointmentId;

  const ConsultationScreen({
    super.key,
    this.patientId,
    this.appointmentId,
  });

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
    _selectedPatientId = widget.patientId;
    _viewModel = sl<ClinicViewModel>()..updateRefresh(() {
      if (mounted) setState(() {});
    });
    _viewModel.clinicCubit.fetchPatients();
    _viewModel.clinicCubit.fetchAppointments();
    _viewModel.clinicCubit.fetchWaitingQueue().then((_) {
      if (_selectedPatientId != null && mounted) {
        _viewModel.clinicCubit.fetchPatientRecord(_selectedPatientId!);
      }
    });
    if (_selectedPatientId != null) {
      _viewModel.clinicCubit.fetchPatientRecord(_selectedPatientId!);
    }
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
    final doctorName = doctor != null ? (doctor['full_name'] ?? 'دكتور العيادة') : 'دكتور العيادة';
    final doctorId = doctor?['id'] ?? 1;
    final nowStr = DateTime.now().toIso8601String().substring(0, 10);

    final patientItem = _viewModel.clinicCubit.patients.firstWhere(
      (p) => p['id'] == _selectedPatientId,
      orElse: () => {'name': 'مريض'},
    );
    final String patientName = patientItem['name'] ?? 'مريض';

    final diagnosis = _viewModel.diagnosisController.text.trim();
    final notes = _viewModel.notesController.text.trim();
    final List<Map<String, dynamic>> rxItems = List.from(_viewModel.prescriptionItems);

    _viewModel.clinicCubit.addPrescription(
      prescription: {
        'appointment_id': widget.appointmentId,
        'patient_id': _selectedPatientId!,
        'doctor_id': doctorId,
        'diagnosis': diagnosis,
        'notes': notes,
        'created_at': nowStr,
      },
      items: rxItems,
    ).then((res) {
      res.fold(
        (err) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message))),
        (_) {
          if (mounted) {
            _showPrescriptionPreviewModal(
              patientName: patientName,
              doctorName: doctorName,
              diagnosis: diagnosis,
              notes: notes,
              dateStr: nowStr,
              items: rxItems,
            );
          }
        },
      );
    });
  }

  Future<void> _completeConsultation() async {
    final queue = _viewModel.clinicCubit.waitingQueue;
    final currentAppt = queue.firstWhere(
      (q) => q['patient_id'] == _selectedPatientId && !AppointmentStatus.fromString(q['status']).isCompleted,
      orElse: () => {},
    );
    if (currentAppt.isNotEmpty) {
      await _viewModel.clinicCubit.updateAppointmentStatus(
        currentAppt['id'] as int,
        AppointmentStatus.completed.dbValue,
      );
    } else if (widget.appointmentId != null) {
      await _viewModel.clinicCubit.updateAppointmentStatus(
        widget.appointmentId!,
        AppointmentStatus.completed.dbValue,
      );
    }

    _viewModel.clearPrescriptionForm();
    setState(() => _selectedPatientId = null);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنهاء الكشف ونقل المريض إلى الكشوفات المكتملة بنجاح!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _showPrescriptionPreviewModal({
    required String patientName,
    required String doctorName,
    required String diagnosis,
    required String notes,
    required String dateStr,
    required List<Map<String, dynamic>> items,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AppDialog(
          title: 'معاينة وحفظ الروشتة الإلكترونية',
          subtitle: 'تم حفظ الكشف والروشتة في قاعدة البيانات بنجاح، اختر الإجراء المطلوب:',
          icon: Icons.receipt_long_rounded,
          iconColor: AppColors.primary,
          maxWidth: 600,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('المريض: $patientName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                        Text('التاريخ: ${DateFormatter.formatDate(dateStr)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('الطبيب المعالج: د. $doctorName', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('التشخيص الطبي: $diagnosis', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('التعليمات: $notes', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.medication_rounded, size: 18, color: AppColors.secondary),
                  const SizedBox(width: 6),
                  Text('الأدويـة المسجلة بالروشتة (${items.length} صنف):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text('لم يتم إضافة أدوبة بالروشتة', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: items.length,
                        itemBuilder: (ctx, idx) {
                          final item = items[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            child: ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 12,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              ),
                              title: Text(item['medicine_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text(
                                'الجرعة: ${item['dosage'] ?? ''} | التكرار: ${item['frequency'] ?? ''} | المدة: ${item['duration'] ?? ''}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          actions: [
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    await _printPrescriptionPdf(
                      patientName: patientName,
                      doctorName: doctorName,
                      diagnosis: diagnosis,
                      notes: notes,
                      dateStr: dateStr,
                      items: items,
                    );
                  },
                  icon: const Icon(Icons.print_rounded, color: Colors.white, size: 18),
                  label: const Text('طباعة الروشتة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    Navigator.of(dialogCtx).pop();
                    await _completeConsultation();
                  },
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  label: const Text('إكمال الكشف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('إلغاء / إغلاق'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _printPrescriptionPdf({
    required String patientName,
    required String doctorName,
    required String diagnosis,
    required String notes,
    required String dateStr,
    required List<Map<String, dynamic>> items,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Smart Clinic - Medical E-Prescription', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Doctor: Dr. $doctorName', style: const pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                    pw.Text('Date: ${DateFormatter.formatDate(dateStr)}', style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 10),
                pw.Text('Patient Name: $patientName', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.Text('Diagnosis: $diagnosis', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                if (notes.isNotEmpty) pw.Text('Instructions: $notes', style: const pw.TextStyle(fontSize: 11)),
                pw.SizedBox(height: 14),
                pw.Text('Prescribed Medications (Rx):', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.TableHelper.fromTextArray(
                  headers: ['#', 'Medicine Name', 'Dosage', 'Frequency', 'Duration'],
                  data: items.asMap().entries.map((e) {
                    final idx = e.key + 1;
                    final item = e.value;
                    return [
                      '$idx',
                      item['medicine_name'] ?? '',
                      item['dosage'] ?? '',
                      item['frequency'] ?? '',
                      item['duration'] ?? '',
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'prescription_${patientName.replaceAll(' ', '_')}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _viewModel.clinicCubit,
      child: Scaffold(
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
    final bool canPop = Navigator.of(context).canPop();
    return Row(
      children: [
        if (canPop) ...[
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'رجوع',
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
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
          ),
        ),
      ],
    );
  }

  void _showPrescriptionDetailModal(Map<String, dynamic> rx) {
    final List items = rx['items'] as List? ?? [];
    final String doctorName = rx['doctor_name'] ?? 'دكتور العيادة';
    final String diagnosis = rx['diagnosis'] ?? 'غير محدد';
    final String dateStr = rx['created_at'] ?? '';
    final String notes = rx['notes'] ?? '';

    final pList = _viewModel.clinicCubit.patients.where((p) => p['id'] == _selectedPatientId).toList();
    final String patientName = pList.isNotEmpty ? (pList.first['name'] ?? 'المريض') : 'المريض';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AppDialog(
          title: 'تفاصيل الروشتة السابقة',
          subtitle: 'تاريخ الصدور: ${DateFormatter.formatDate(dateStr)} | الطبيب: د. $doctorName',
          icon: Icons.receipt_long_rounded,
          iconColor: AppColors.primary,
          maxWidth: 550,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.medical_information_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'التشخيص الطبي: $diagnosis',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('الأدويـة والجرعـات المقررة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: items.isEmpty
                    ? const Text('لا توجد عناصر أدوية مسجلة في هذه الروشتة.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: items.length,
                        itemBuilder: (ctx, idx) {
                          final item = items[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            child: ListTile(
                              dense: true,
                              leading: const CircleAvatar(
                                radius: 12,
                                backgroundColor: AppColors.secondary,
                                child: Icon(Icons.medication_rounded, size: 12, color: Colors.white),
                              ),
                              title: Text(item['medicine_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text(
                                'الجرعة: ${item['dosage'] ?? ''} | التكرار: ${item['frequency'] ?? ''} | المدة: ${item['duration'] ?? ''}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('تعليمات وإرشادات الطبيب: $notes', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
              ],
            ],
          ),
          actions: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () async {
                    await _printPrescriptionPdf(
                      patientName: patientName,
                      doctorName: doctorName,
                      diagnosis: diagnosis,
                      notes: notes,
                      dateStr: dateStr,
                      items: List<Map<String, dynamic>>.from(items),
                    );
                  },
                  icon: const Icon(Icons.print_rounded, color: Colors.white, size: 16),
                  label: const Text('طباعة الروشتة', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('إغلاق'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPatientSelectorCard() {
    final rawPatients = _viewModel.clinicCubit.patients;
    final uniquePatientsMap = <int, Map<String, dynamic>>{};
    for (final p in rawPatients) {
      final id = p['id'] as int?;
      if (id != null && !uniquePatientsMap.containsKey(id)) {
        uniquePatientsMap[id] = p;
      }
    }
    final patients = uniquePatientsMap.values.toList();
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
                  child: Text('${p['name']} (${p['phone'] ?? ''})', overflow: TextOverflow.ellipsis),
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
                Text('قم باختيار مريض لعرض بياناته السريرية والروشتات السابقة والتنبيهات الطبية', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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

    final rxRecord = _viewModel.clinicCubit.selectedPatientRecord;
    final List prescsList = rxRecord != null ? (rxRecord['prescriptions'] as List? ?? []) : [];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
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
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PatientDetailHubScreen(patient: p),
                        ),
                      );
                    },
                    icon: const Icon(Icons.folder_shared_rounded, size: 14, color: AppColors.primary),
                    label: const Text('الملف الطبي (EMR)', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 14),

              // Timeline of Previous Prescriptions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.history_edu_rounded, size: 16, color: AppColors.secondary),
                      SizedBox(width: 6),
                      Text('الروشتات والزيارات السابقة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  Text('${prescsList.length} روشتة', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),

              if (prescsList.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('لا توجد روشتات سابقة مسجلة لهذا المريض', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: prescsList.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (ctx, idx) {
                    final rx = prescsList[idx];
                    final List items = rx['items'] as List? ?? [];
                    final String date = rx['created_at'] ?? '';
                    final String diagnosis = rx['diagnosis'] ?? 'غير محدد';
                    return InkWell(
                      onTap: () => _showPrescriptionDetailModal(rx),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('تاريخ: ${DateFormatter.formatDate(date)} | التشخيص: $diagnosis', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text('عدد الأدوية: ${items.length} صنف', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textLight),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
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
