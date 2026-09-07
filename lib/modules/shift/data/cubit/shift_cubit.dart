import 'package:dartz/dartz.dart';
import '../../../../core/common/error_handler/failure.dart';
import '../../../shared/cubit/base_cubit.dart';
import '../repo/shift_repo.dart';

enum ShiftApiType { none, getActiveShift, startShift, closeShift, getHistory }

class ShiftCubit extends BaseCubit<ShiftApiType> {
  final ShiftRepo _shiftRepo;

  ShiftCubit(this._shiftRepo) : super(ShiftApiType.none);

  Map<String, dynamic>? activeShift;
  List<Map<String, dynamic>> shiftHistory = [];

  Future<Either<Failure, Map<String, dynamic>?>> fetchActiveShift(int userId) async {
    return await fastFire(
      type: ShiftApiType.getActiveShift,
      fun: () => _shiftRepo.getActiveShift(userId),
      onSuccess: (shift) {
        activeShift = shift;
      },
    );
  }

  Future<Either<Failure, Map<String, dynamic>>> startShift({
    required int userId,
    required double startingCash,
    required String startTime,
    String? notes,
  }) async {
    return await fastFire(
      type: ShiftApiType.startShift,
      fun: () => _shiftRepo.startShift(userId: userId, startingCash: startingCash, startTime: startTime, notes: notes),
      onSuccess: (shift) {
        activeShift = shift;
      },
    );
  }

  Future<Either<Failure, void>> closeShift({
    required int shiftId,
    required double endingCash,
    String? notes,
  }) async {
    return await fastFire(
      type: ShiftApiType.closeShift,
      fun: () => _shiftRepo.closeShift(shiftId: shiftId, endingCash: endingCash, notes: notes),
      onSuccess: (_) {
        activeShift = null;
      },
    );
  }

  Future<Either<Failure, List<Map<String, dynamic>>>> fetchHistory(int userId) async {
    return await fastFire(
      type: ShiftApiType.getHistory,
      fun: () => _shiftRepo.getShiftsHistory(userId),
      onSuccess: (list) {
        shiftHistory = list;
      },
    );
  }
}
