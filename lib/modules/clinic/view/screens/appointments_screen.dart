import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/common/widgets/app_dialog.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/security/session_manager.dart';
import '../../../../core/security/shift_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../shared/cubit/block_builder_widget.dart';
import '../../../shift/view/shift_screen.dart';
import '../../data/cubit/clinic_cubit.dart';
import '../clinic_view_model.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  late final ClinicViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = sl<ClinicViewModel>()..updateRefresh(() {
      if (mounted) setState(() {});
    });
    _viewModel.clinicCubit.fetchAppointments();
    _viewModel.clinicCubit.fetchPatients();
    _viewModel.clinicCubit.fetchUsers();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _onAddAppointmentClick() {
    final hasShift = ShiftGuard.checkShiftOrWarn(
      context,
      onNavigateToShift: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShiftScreen()));
      },
    );

    if (hasShift) {
      _showBookingDialog(context);
    }
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
            // Responsive Header
            if (isMobile) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('جدول المواعيد والحجوزات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('إدارة وتنظيم زيارات العيادة', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _onAddAppointmentClick,
                      icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
                      label: const Text('تسجيل موعد جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                      Text('جدول المواعيد والحجوزات', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('إدارة حجز المواعيد وتنظيم جدول زيارات العيادة', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _onAddAppointmentClick,
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                    label: const Text('تسجيل موعد جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Expanded(
              child: BlockBuilderWidget<ClinicCubit, ClinicApiType>(
                types: const [ClinicApiType.getAppointments],
                body: (_) => _buildAppointmentsTable(),
                loading: (_) => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsTable() {
    final list = _viewModel.clinicCubit.appointments;
    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_month_outlined, size: 54, color: AppColors.textLight),
              SizedBox(height: 12),
              Text('لا توجد مواعيد مسجلة حتى الآن في النظام', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        itemCount: list.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final appt = list[index];
          final String priority = appt['priority'] ?? 'عادي';
          final bool isUrgent = priority == 'مستعجل' || priority == 'حالة طارئة';

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: isUrgent ? AppColors.error.withValues(alpha: 0.15) : AppColors.primaryLight,
              child: Text(
                '#${appt['id']}',
                style: TextStyle(color: isUrgent ? AppColors.error : AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    appt['patient_name'] ?? 'مريض غير معروف',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isUrgent ? AppColors.error.withValues(alpha: 0.12) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    priority,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isUrgent ? AppColors.error : Colors.black87),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              'التاريخ: ${appt['appointment_date']} | التوقيت: ${appt['time_slot']} | النوع: ${appt['type']} | الطبيب: ${appt['doctor_name'] ?? 'غير محدد'}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(appt['status']).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                appt['status'] ?? 'منتظر',
                style: TextStyle(color: _getStatusColor(appt['status']), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'منتظر':
        return Colors.amber[800]!;
      case 'في الكشف':
        return AppColors.secondary;
      case 'مكتمل':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  void _showBookingDialog(BuildContext context) {
    final patients = _viewModel.clinicCubit.patients;
    final users = _viewModel.clinicCubit.usersList;

    int? selectedPatientId = patients.isNotEmpty ? patients.first['id'] as int : null;
    String selectedType = 'كشف عادي';
    String selectedPriority = 'عادي';

    final String defaultDoctorName = users.isNotEmpty ? (users.first['full_name'] ?? 'د. محمد حسن') : 'د. محمد حسن';
    String selectedDoctor = defaultDoctorName;

    final notesController = TextEditingController();
    DateTime bookingDate = DateTime.now();
    TimeOfDay bookingTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final formattedDate = DateFormat('yyyy-MM-dd').format(bookingDate);
          final formattedTime = bookingTime.format(context);

          return AppDialog(
            title: 'تسجيل موعد جديد',
            subtitle: 'أدخل بيانات الحجز والمريض لإنشاء موعد في النظام',
            icon: Icons.calendar_month_rounded,
            iconColor: AppColors.primary,
            maxWidth: 560,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (patients.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ملاحظة: سيتم إنشاء سجل مريض جديد تلقائياً عند تأكيد الحجز.',
                            style: TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Appointment Type Selector
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: InputDecoration(
                    labelText: 'نوع الموعد (كشف/استشارة/متابعة) *',
                    prefixIcon: const Icon(Icons.medical_services_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'كشف عادي', child: Text('كشف عادي')),
                    DropdownMenuItem(value: 'استشارة', child: Text('استشارة')),
                    DropdownMenuItem(value: 'متابعة دورية', child: Text('متابعة دورية')),
                    DropdownMenuItem(value: 'كشف مستعجل', child: Text('كشف مستعجل')),
                  ],
                  onChanged: (val) => setDialogState(() => selectedType = val!),
                ),
                const SizedBox(height: 14),

                // Patient Selector Dropdown
                if (patients.isNotEmpty) ...[
                  DropdownButtonFormField<int>(
                    initialValue: selectedPatientId,
                    decoration: InputDecoration(
                      labelText: 'اختر المريض *',
                      prefixIcon: const Icon(Icons.person_pin_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: patients.map((p) {
                      return DropdownMenuItem<int>(
                        value: p['id'] as int,
                        child: Text('#${p['id']} - ${p['name']} (${p['phone'] ?? ''})'),
                      );
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedPatientId = val),
                  ),
                  const SizedBox(height: 14),
                ],

                // Date & Time Row Pickers
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: bookingDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 1)),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (picked != null) {
                            setDialogState(() => bookingDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'تاريخ الحجز *',
                            prefixIcon: const Icon(Icons.calendar_month),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: bookingTime,
                          );
                          if (picked != null) {
                            setDialogState(() => bookingTime = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'وقت الحجز *',
                            prefixIcon: const Icon(Icons.access_time),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(formattedTime, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Assigned Doctor Selector
                DropdownButtonFormField<String>(
                  initialValue: selectedDoctor,
                  decoration: InputDecoration(
                    labelText: 'الطبيب المعالج *',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: users.isEmpty
                      ? const [DropdownMenuItem(value: 'د. محمد حسن', child: Text('د. محمد حسن'))]
                      : users.map((u) {
                          final name = u['full_name'] ?? 'د. محمد حسن';
                          return DropdownMenuItem<String>(
                            value: name,
                            child: Text(name.startsWith('د.') ? name : 'د. $name'),
                          );
                        }).toList(),
                  onChanged: (val) => setDialogState(() => selectedDoctor = val!),
                ),
                const SizedBox(height: 14),

                // Notes Field
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'سبب الزيارة / الشكوى الرئيسية (اختياري)',
                    prefixIcon: const Icon(Icons.notes),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),

                // Priority Selector Chips
                const Text('أولوية الحجز:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['عادي', 'مستعجل', 'حالة طارئة'].map((p) {
                    final isSelected = selectedPriority == p;
                    return FilterChip(
                      selected: isSelected,
                      selectedColor: p == 'عادي' ? AppColors.primary : AppColors.error,
                      label: Text(
                        p,
                        style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                      ),
                      onSelected: (_) => setDialogState(() => selectedPriority = p),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final user = SessionManager.instance.currentUser;
                  final shift = SessionManager.instance.activeShift;

                  int pId = selectedPatientId ?? 1;

                  if (patients.isEmpty) {
                    final newP = await _viewModel.clinicCubit.addPatient({
                      'name': 'مريض موعد جديد',
                      'phone': '01000000000',
                      'created_at': formattedDate,
                    });
                    newP.fold((_) {}, (id) => pId = id);
                  }

                  await _viewModel.clinicCubit.addAppointment({
                    'patient_id': pId,
                    'user_id': user != null ? user['id'] : 1,
                    'shift_id': shift != null ? shift['id'] : 1,
                    'appointment_date': formattedDate,
                    'time_slot': formattedTime,
                    'type': selectedType,
                    'status': 'منتظر',
                    'fee': 0.0,
                    'doctor_name': selectedDoctor,
                    'notes': notesController.text.trim(),
                    'priority': selectedPriority,
                  });

                  if (dialogCtx.mounted) {
                    Navigator.of(dialogCtx).pop();
                  }
                  _viewModel.clinicCubit.fetchAppointments();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تسجيل وتأكيد الموعد بنجاح!'), backgroundColor: AppColors.success),
                    );
                  }
                },
                child: const Text('تأكيد الحجز', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}
