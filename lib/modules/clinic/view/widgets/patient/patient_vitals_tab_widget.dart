import 'package:flutter/material.dart';
import '../../../../../core/common/widgets/app_dialog.dart';
import '../../../../../core/security/shift_guard.dart';
import '../../../../../core/theme/app_colors.dart';

class PatientVitalsTabWidget extends StatefulWidget {
  final Map<String, dynamic> patientRecord;
  final Function(Map<String, dynamic> vitalData)? onSaveVital;

  const PatientVitalsTabWidget({
    super.key,
    required this.patientRecord,
    this.onSaveVital,
  });

  @override
  State<PatientVitalsTabWidget> createState() => _PatientVitalsTabWidgetState();
}

class _PatientVitalsTabWidgetState extends State<PatientVitalsTabWidget> {
  final List<Map<String, dynamic>> _vitalsList = [];

  @override
  void initState() {
    super.initState();
    // Load vitals from patient record if present, otherwise set demo baseline
    final recordVitals = widget.patientRecord['vitals'] as List?;
    if (recordVitals != null && recordVitals.isNotEmpty) {
      _vitalsList.addAll(recordVitals.cast<Map<String, dynamic>>());
    }
  }

  void _showAddVitalsDialog(BuildContext context) {
    if (!ShiftGuard.checkShiftOrWarn(context)) return;

    final sysCtrl = TextEditingController(text: '120');
    final diaCtrl = TextEditingController(text: '80');
    final pulseCtrl = TextEditingController(text: '72');
    final tempCtrl = TextEditingController(text: '36.8');
    final weightCtrl = TextEditingController(text: '70');
    final heightCtrl = TextEditingController(text: '170');
    final spo2Ctrl = TextEditingController(text: '98');
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final double weight = double.tryParse(weightCtrl.text) ?? 0;
          final double heightCm = double.tryParse(heightCtrl.text) ?? 0;
          double bmi = 0;
          if (weight > 0 && heightCm > 0) {
            final double heightM = heightCm / 100.0;
            bmi = weight / (heightM * heightM);
          }

          return AppDialog(
            title: 'إدخال العلامات الحيوية الجديدة',
            subtitle: 'سجّل الفحوصات القياسية الميدانية للمريض قبل الكشف',
            icon: Icons.monitor_heart_rounded,
            iconColor: AppColors.primary,
            maxWidth: 520,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('1. ضغط الدم والنبض:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: sysCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'انقباضي (Systolic) *', suffixText: 'mmHg'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: diaCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'انبساطي (Diastolic) *', suffixText: 'mmHg'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: pulseCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'النبض (Pulse) *', suffixText: 'bpm'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const Text('2. الحرارة ونسبة الأكسجين:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: tempCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'الحرارة *', suffixText: '°C'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: spo2Ctrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'نسبة الأكسجين SpO2', suffixText: '%'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const Text('3. الوزن والطول ومؤشر كتلة الجسم (BMI):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: weightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'الوزن *', suffixText: 'kg'),
                        onChanged: (_) => setModalState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: heightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'الطول *', suffixText: 'cm'),
                        onChanged: (_) => setModalState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          const Text('BMI', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          Text(
                            bmi > 0 ? bmi.toStringAsFixed(1) : '--',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'ملاحظات وتنبيهات ممرض/طبيب القياس'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () {
                  final newVital = {
                    'date': DateTime.now().toString().substring(0, 16),
                    'systolic': int.tryParse(sysCtrl.text) ?? 120,
                    'diastolic': int.tryParse(diaCtrl.text) ?? 80,
                    'pulse': int.tryParse(pulseCtrl.text) ?? 72,
                    'temp': double.tryParse(tempCtrl.text) ?? 36.8,
                    'weight': double.tryParse(weightCtrl.text) ?? 70.0,
                    'height': double.tryParse(heightCtrl.text) ?? 170.0,
                    'spo2': int.tryParse(spo2Ctrl.text) ?? 98,
                    'bmi': bmi > 0 ? double.parse(bmi.toStringAsFixed(1)) : 24.2,
                    'notes': notesCtrl.text.trim(),
                  };
                  setState(() {
                    _vitalsList.insert(0, newVital);
                  });
                  if (widget.onSaveVital != null) {
                    widget.onSaveVital!(newVital);
                  }
                  Navigator.of(dialogCtx).pop();
                },
                icon: const Icon(Icons.check, color: Colors.white, size: 18),
                label: const Text('حفظ القياسات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('سجل العلامات الحيوية والقياسات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('تتبع ضغط الدم، النبض، الحرارة، الوزن ومؤشر BMI', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showAddVitalsDialog(context),
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('إدخال قياس جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Content List
          Expanded(
            child: _vitalsList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.monitor_heart_outlined, size: 48, color: AppColors.textLight),
                        const SizedBox(height: 12),
                        const Text('لا توجد قياسات حيوية سابقة مسجلة لهذا المريض', style: TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          onPressed: () => _showAddVitalsDialog(context),
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text('إدخال أول قياس سريري', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _vitalsList.length,
                    itemBuilder: (context, index) {
                      final v = _vitalsList[index];
                      final int sys = (v['systolic'] as num?)?.toInt() ?? 120;
                      final int dia = (v['diastolic'] as num?)?.toInt() ?? 80;
                      final int pulse = (v['pulse'] as num?)?.toInt() ?? 72;
                      final double temp = (v['temp'] as num?)?.toDouble() ?? 36.8;
                      final double weight = (v['weight'] as num?)?.toDouble() ?? 70;
                      final int spo2 = (v['spo2'] as num?)?.toInt() ?? 98;
                      final double bmi = (v['bmi'] as num?)?.toDouble() ?? 24.2;

                      final bool isHighBp = sys >= 140 || dia >= 90;
                      final bool isFever = temp >= 38.0;

                      return Card(
                        elevation: 1.5,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textSecondary),
                                      const SizedBox(width: 6),
                                      Text(
                                        'تاريخ القياس: ${v['date'] ?? ''}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  if (isHighBp || isFever)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isHighBp ? 'ضغط مرتفع!' : 'ارتفاع حرارة!',
                                        style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                ],
                              ),
                              const Divider(height: 16),
                              Wrap(
                                spacing: 12,
                                runSpacing: 10,
                                children: [
                                  _VitalChip(label: 'ضغط الدم', value: '$sys/$dia mmHg', icon: Icons.favorite, color: isHighBp ? AppColors.error : AppColors.primary),
                                  _VitalChip(label: 'النبض', value: '$pulse bpm', icon: Icons.speed, color: Colors.teal),
                                  _VitalChip(label: 'الحرارة', value: '$temp °C', icon: Icons.thermostat, color: isFever ? Colors.orange : Colors.deepOrange),
                                  _VitalChip(label: 'SpO2', value: '$spo2%', icon: Icons.air, color: Colors.blue),
                                  _VitalChip(label: 'الوزن', value: '$weight kg', icon: Icons.scale, color: Colors.indigo),
                                  _VitalChip(label: 'BMI', value: bmi.toStringAsFixed(1), icon: Icons.fitness_center, color: Colors.purple),
                                ],
                              ),
                              if (v['notes'] != null && (v['notes'] as String).isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text('ملاحظات: ${v['notes']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _VitalChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _VitalChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
              Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
