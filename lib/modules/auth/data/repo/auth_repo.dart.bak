import 'package:dartz/dartz.dart';
import '../../../../core/common/error_handler/failure.dart';
import '../../../../core/database/database_helper.dart';

abstract class AuthRepo {
  Future<Either<Failure, Map<String, dynamic>>> login({
    required String username,
    required String password,
  });
}

class AuthRepoImpl implements AuthRepo {
  @override
  Future<Either<Failure, Map<String, dynamic>>> login({
    required String username,
    required String password,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'users',
        where: 'username = ? AND password = ? AND is_active = 1',
        whereArgs: [username.trim(), password.trim()],
      );

      if (result.isNotEmpty) {
        return Right(result.first);
      } else {
        return const Left(Failure(401, 'اسم المستخدم أو كلمة المرور غير صحيحة'));
      }
    } catch (e) {
      return Left(Failure(500, 'حدث خطأ أثناء الاتصال بقاعدة البيانات: $e'));
    }
  }
}
