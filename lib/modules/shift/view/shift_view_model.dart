import 'package:flutter/material.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/database/database_helper.dart';
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

  Future<int> _getOrInsertUserId(Map<String, dynamic> user) async {
    if (user['id'] is int) {
      return user['id'] as int;
    }

    final parsedId = int.tryParse(user['id'].toString());
    if (parsedId != null) {
      return parsedId;
    }

    final db = await DatabaseHelper.instance.database;
    final userRows = await db.query(
      'users',
      where: 'remote_id = ?',
      whereArgs: [user['id']],
    );

    if (userRows.isEmpty) {
      return await db.insert('users', {
        'remote_id': user['id'],
        'full_name': user['full_name'] ?? '',
        'username': user['username'] ?? '',
        'email': user['email'] ?? '',
        'role': user['role'] ?? 'doctor',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    return userRows.first['id'] as int;
  }

  Future<void> checkInitialShift() async {
    final user = SessionManager.instance.currentUser;
    if (user == null) return;
    final userId = await _getOrInsertUserId(user);

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

    final userId = await _getOrInsertUserId(user);
    final double startingCash = double.tryParse(startingCashController.text) ?? 0.0;
    final String notes = notesController.text;
    final String dateStr = dateController.text;
    final String timeStr = timeController.text;
    final String fullStartTimeStr = '$dateStr | $timeStr';

    final result = await shiftCubit.startShift(
      userId: userId,
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
