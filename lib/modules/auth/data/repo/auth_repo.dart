import 'package:dartz/dartz.dart';
import '../../../../core/common/error_handler/app_logger.dart';
import '../../../../core/common/error_handler/failure.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/security/password_hasher.dart';

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
      final cleanUsername = username.trim();
      final cleanPassword = password.trim();

      final result = await db.query(
        'users',
        where: 'username = ? AND is_active = 1 AND (is_deleted = 0 OR is_deleted IS NULL)',
        whereArgs: [cleanUsername],
      );

      if (result.isEmpty) {
        return const Left(Failure(401, 'اسم المستخدم غير موجود أو الحساب معطل'));
      }

      final userMap = Map<String, dynamic>.from(result.first);
      final storedHash = userMap['password_hash'] as String?;
      final storedPlain = userMap['password'] as String?;

      bool isValid = false;

      // 1. Try checking against BCrypt hash if present
      if (storedHash != null && storedHash.isNotEmpty) {
        isValid = PasswordHasher.verifyPassword(cleanPassword, storedHash);
      } 
      // 2. Fallback to plaintext comparison (Lazy Migration scenario)
      if (!isValid && storedPlain != null && storedPlain.isNotEmpty) {
        isValid = PasswordHasher.verifyPassword(cleanPassword, storedPlain);
      }

      if (!isValid) {
        return const Left(Failure(401, 'كلمة المرور غير صحيحة'));
      }

      // 3. Lazy Migration to BCrypt if password_hash is missing
      if (storedHash == null || storedHash.isEmpty) {
        try {
          final newHash = PasswordHasher.hashPassword(cleanPassword);
          await db.update(
            'users',
            {'password_hash': newHash},
            where: 'id = ?',
            whereArgs: [userMap['id']],
          );
          userMap['password_hash'] = newHash;
          AppLogger.info('Lazy migrated password to BCrypt hash for user ID: ${userMap['id']}');
        } catch (e) {
          AppLogger.error('Failed to perform lazy migration for BCrypt password hash', e);
        }
      }

      return Right(userMap);
    } catch (e) {
      AppLogger.error('Login database error', e);
      return Left(Failure(500, 'حدث خطأ أثناء تسجيل الدخول: $e'));
    }
  }
}
