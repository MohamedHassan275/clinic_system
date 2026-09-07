import 'package:dartz/dartz.dart';
import '../../../../core/common/error_handler/failure.dart';
import '../../../../core/database/database_helper.dart';

abstract class ShiftRepo {
  Future<Either<Failure, Map<String, dynamic>?>> getActiveShift(int userId);
  Future<Either<Failure, Map<String, dynamic>>> startShift({
    required int userId,
    required double startingCash,
    required String startTime,
    String? notes,
  });
  Future<Either<Failure, void>> closeShift({
    required int shiftId,
    required double endingCash,
    String? notes,
  });
  Future<Either<Failure, List<Map<String, dynamic>>>> getShiftsHistory(int userId);
}

class ShiftRepoImpl implements ShiftRepo {
  @override
  Future<Either<Failure, Map<String, dynamic>?>> getActiveShift(int userId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'shifts',
        where: 'user_id = ? AND is_closed = 0',
        whereArgs: [userId],
        orderBy: 'id DESC',
        limit: 1,
      );
      if (result.isNotEmpty) {
        return Right(result.first);
      }
      return const Right(null);
    } catch (e) {
      return Left(Failure(500, 'فشل الاستعلام عن الوردية الحالية: $e'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> startShift({
    required int userId,
    required double startingCash,
    required String startTime,
    String? notes,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final shiftData = {
        'user_id': userId,
        'start_time': startTime,
        'starting_cash': startingCash,
        'ending_cash': 0.0,
        'is_closed': 0,
        'notes': notes ?? '',
      };
      final id = await db.insert('shifts', shiftData);
      return Right({...shiftData, 'id': id});
    } catch (e) {
      return Left(Failure(500, 'فشل بدء الوردية: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> closeShift({
    required int shiftId,
    required double endingCash,
    String? notes,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final nowStr = DateTime.now().toIso8601String();
      await db.update(
        'shifts',
        {
          'end_time': nowStr,
          'ending_cash': endingCash,
          'is_closed': 1,
          'notes': notes,
        },
        where: 'id = ?',
        whereArgs: [shiftId],
      );
      return const Right(null);
    } catch (e) {
      return Left(Failure(500, 'فشل إغلاق الوردية: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getShiftsHistory(int userId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'shifts',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'id DESC',
      );
      return Right(result);
    } catch (e) {
      return Left(Failure(500, 'فشل جلب سجل الورديات: $e'));
    }
  }
}
