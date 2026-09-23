import 'package:flutter/material.dart';
import '../../../modules/clinic/view/screens/sync_status_screen.dart';
import '../../theme/app_colors.dart';
import '../sync_service.dart';

class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: SyncService.instance.statusNotifier,
      builder: (context, status, _) {
        IconData icon;
        Color color;
        String tooltip;

        switch (status) {
          case SyncStatus.connected:
            icon = Icons.cloud_done_rounded;
            color = AppColors.success;
            tooltip = 'المزامنة متصلة ومنتظمة';
            break;
          case SyncStatus.syncing:
            icon = Icons.cloud_sync_rounded;
            color = Colors.amber.shade700;
            tooltip = 'جاري مزامنة البيانات...';
            break;
          case SyncStatus.offline:
            icon = Icons.cloud_off_rounded;
            color = Colors.grey.shade600;
            tooltip = 'غير متصل بالسحابة (Offline)';
            break;
          case SyncStatus.error:
            icon = Icons.cloud_queue_rounded;
            color = AppColors.error;
            tooltip = 'حدث خطأ أثناء المزامنة';
            break;
        }

        return Tooltip(
          message: tooltip,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SyncStatusScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 4),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
