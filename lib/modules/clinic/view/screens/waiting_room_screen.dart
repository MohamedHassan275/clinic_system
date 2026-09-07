import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../shared/cubit/block_builder_widget.dart';
import '../../data/cubit/clinic_cubit.dart';
import '../clinic_view_model.dart';

class WaitingRoomScreen extends StatefulWidget {
  const WaitingRoomScreen({super.key});

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  late final ClinicViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = sl<ClinicViewModel>()..updateRefresh(() {
      if (mounted) setState(() {});
    });
    _viewModel.clinicCubit.fetchWaitingQueue();
  }

  @override
  void dispose() {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('غرفة الانتظار والاستقبال', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('متابعة دورية المرضى بالترتيب ونداء الحالات للغرفة الطبية', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _viewModel.clinicCubit.fetchWaitingQueue(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: BlockBuilderWidget<ClinicCubit, ClinicApiType>(
                types: const [ClinicApiType.getWaitingRoom],
                body: (_) => _buildQueueList(),
                loading: (_) => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueList() {
    final queue = _viewModel.clinicCubit.waitingQueue;
    if (queue.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 56, color: AppColors.textLight),
            SizedBox(height: 12),
            Text('غرفة الانتظار فارغة حالياً', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        itemCount: queue.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = queue[index];
          final bool isInside = item['status'] == 'في الكشف';
          return ListTile(
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: isInside ? AppColors.secondary : AppColors.primaryLight,
              child: Text('${index + 1}', style: TextStyle(color: isInside ? Colors.white : AppColors.primary, fontWeight: FontWeight.bold)),
            ),
            title: Text(item['patient_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text('رقم الموعد: #${item['id']} | الهاتف: ${item['patient_phone']}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isInside)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                    onPressed: () async {
                      await _viewModel.clinicCubit.updateAppointmentStatus(item['id'] as int, 'في الكشف');
                      _viewModel.clinicCubit.fetchWaitingQueue();
                    },
                    icon: const Icon(Icons.meeting_room, size: 16, color: Colors.white),
                    label: const Text('إدخال للكشف', style: TextStyle(color: Colors.white)),
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                    onPressed: () async {
                      await _viewModel.clinicCubit.updateAppointmentStatus(item['id'] as int, 'مكتمل');
                      _viewModel.clinicCubit.fetchWaitingQueue();
                    },
                    icon: const Icon(Icons.check, size: 16, color: Colors.white),
                    label: const Text('إنهاء الكشف', style: TextStyle(color: Colors.white)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
