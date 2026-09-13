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
    final media = MediaQuery.of(context);
    final bool isMobile = media.size.width < 768;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 14.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('غرفة الانتظار والاستقبال', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('متابعة دورية المرضى بالترتيب ونداء الحالات للغرفة الطبية', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _viewModel.clinicCubit.fetchWaitingQueue(),
                  tooltip: 'تحديث الدور',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: BlockBuilderWidget<ClinicCubit, ClinicApiType>(
                types: const [ClinicApiType.getWaitingRoom],
                body: (_) => _buildQueueList(isMobile),
                loading: (_) => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueList(bool isMobile) {
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: isInside ? AppColors.secondary : AppColors.primaryLight,
              child: Text('${index + 1}', style: TextStyle(color: isInside ? Colors.white : AppColors.primary, fontWeight: FontWeight.bold)),
            ),
            title: Text(item['patient_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text('رقم الموعد: #${item['id']} | الهاتف: ${item['patient_phone'] ?? 'بدون'}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isInside)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      await _viewModel.clinicCubit.updateAppointmentStatus(item['id'] as int, 'في الكشف');
                      _viewModel.clinicCubit.fetchWaitingQueue();
                    },
                    icon: const Icon(Icons.meeting_room, size: 16, color: Colors.white),
                    label: Text(isMobile ? 'دخول' : 'إدخال للكشف', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      await _viewModel.clinicCubit.updateAppointmentStatus(item['id'] as int, 'مكتمل');
                      _viewModel.clinicCubit.fetchWaitingQueue();
                    },
                    icon: const Icon(Icons.check, size: 16, color: Colors.white),
                    label: Text(isMobile ? 'إنهاء' : 'إنهاء الكشف', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
