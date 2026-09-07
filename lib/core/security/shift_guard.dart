import 'package:flutter/material.dart';
import '../../modules/shift/view/shift_screen.dart';
import '../theme/app_colors.dart';
import 'session_manager.dart';

class ShiftGuard {
  ShiftGuard._();

  /// Returns true if active shift exists. If not, presents a mandatory warning modal dialog.
  static bool checkShiftOrWarn(BuildContext context, {VoidCallback? onNavigateToShift}) {
    if (SessionManager.instance.hasActiveShift) {
      return true;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 30),
            SizedBox(width: 10),
            Text('تنبيه: يلزم فتح وردية نشطة أولاً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'عذراً، لا يمكن إجراء الحجوزات، إضافة المرضى، تحرير الروشتات، أو إصدار الفواتير دون فتح وردية مالية نشطة أولاً.\n\n'
          'يرجى فتح وردية جديدة وتسليم العهدة لتشغيل عمليات النظام.',
          style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (onNavigateToShift != null) {
                onNavigateToShift();
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ShiftScreen()),
                );
              }
            },
            icon: const Icon(Icons.access_time_filled, size: 18),
            label: const Text('بدء وإدارة الوردية الآن ⏰', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    return false;
  }
}
