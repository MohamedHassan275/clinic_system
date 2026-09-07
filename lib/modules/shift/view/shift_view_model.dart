import 'package:flutter/material.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/security/session_manager.dart';
import '../data/cubit/shift_cubit.dart';

class ShiftViewModel extends BaseViewModel {
  final ShiftCubit shiftCubit;

  ShiftViewModel(super.reLoad, this.shiftCubit);

  final TextEditingController startingCashController = TextEditingController(text: '1000.0');
  final TextEditingController notesController = TextEditingController();
  final TextEditingController endingCashController = TextEditingController();

  final TextEditingController dateController = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  late final TextEditingController timeController = TextEditingController(
    text: _formatTimeOfDay(TimeOfDay.now()),
  );
  TimeOfDay selectedTime = TimeOfDay.now();

  static String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'ص' : 'م';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  Future<void> selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (picked != null) {
      selectedTime = picked;
      timeController.text = _formatTimeOfDay(picked);
      notifyListeners();
    }
  }

  Future<void> checkInitialShift() async {
    final user = SessionManager.instance.currentUser;
    if (user == null) return;
    final userId = user['id'] as int;

    final result = await shiftCubit.fetchActiveShift(userId);
    result.fold(
      (l) {},
      (shift) {
        SessionManager.instance.setActiveShift(shift);
        notifyListeners();
      },
    );
  }

  Future<void> startNewShift({
    required VoidCallback onSuccess,
    required Function(String err) onError,
  }) async {
    final user = SessionManager.instance.currentUser;
    if (user == null) {
      onError('لا توجد جلسة مستخدم مفعّلة');
      return;
    }

    final double startingCash = double.tryParse(startingCashController.text) ?? 0.0;
    final String notes = notesController.text;
    final String dateStr = dateController.text;
    final String timeStr = timeController.text;
    final String fullStartTimeStr = '$dateStr | $timeStr';

    final result = await shiftCubit.startShift(
      userId: user['id'] as int,
      startingCash: startingCash,
      startTime: fullStartTimeStr,
      notes: notes,
    );

    result.fold(
      (failure) => onError(failure.message),
      (shiftMap) {
        SessionManager.instance.setActiveShift(shiftMap);
        onSuccess();
      },
    );
  }

  Future<void> closeCurrentShift({
    required VoidCallback onSuccess,
    required Function(String err) onError,
  }) async {
    final activeShift = SessionManager.instance.activeShift;
    if (activeShift == null) return;

    final double endingCash = double.tryParse(endingCashController.text) ?? 0.0;

    final result = await shiftCubit.closeShift(
      shiftId: activeShift['id'] as int,
      endingCash: endingCash,
      notes: 'تم إغلاق الوردية يدوياً',
    );

    result.fold(
      (failure) => onError(failure.message),
      (_) {
        SessionManager.instance.setActiveShift(null);
        onSuccess();
      },
    );
  }

  @override
  void dispose() {
    startingCashController.dispose();
    notesController.dispose();
    endingCashController.dispose();
    dateController.dispose();
    timeController.dispose();
    shiftCubit.close();
    super.dispose();
  }
}
