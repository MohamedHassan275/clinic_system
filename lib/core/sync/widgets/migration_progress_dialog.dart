import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../sync_service.dart';

class MigrationProgressDialog extends StatelessWidget {
  const MigrationProgressDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MigrationProgress>(
      valueListenable: SyncService.instance.migrationProgressNotifier,
      builder: (context, progress, _) {
        final pctDisplay = (progress.percentage * 100).clamp(0.0, 100.0);

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.cloud_download_rounded, color: AppColors.primary),
              SizedBox(width: 10),
              Text('الهجرة الأولى للبيانات'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'جاري نقل المزامنة السحابية للجدول: ${progress.currentTable.isNotEmpty ? progress.currentTable : "الافتتاحي"}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress.percentage,
                backgroundColor: Colors.grey.shade200,
                color: AppColors.primary,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('الصفوف المعالجة: ${progress.processedRows} / ${progress.totalRows}'),
                  Text('${pctDisplay.toStringAsFixed(1)}%'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
