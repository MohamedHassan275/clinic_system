import 'package:dartz/dartz.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/common/error_handler/app_logger.dart';
import '../../../../core/common/error_handler/failure.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/enums/database_type.dart';
import '../../../../core/security/password_hasher.dart';
import '../../../../core/sync/sync_service.dart';

abstract class AuthRepo {
  Future<Either<Failure, Map<String, dynamic>>> login({
    required String username,
    required String password,
    DatabaseType databaseType = DatabaseType.offline,
  });
}

class AuthRepoImpl implements AuthRepo {
  final AuthService _authService = AuthService();

  @override
  Future<Either<Failure, Map<String, dynamic>>> login({
    required String username,
    required String password,
    DatabaseType databaseType = DatabaseType.offline,
  }) async {
    switch (databaseType) {
      case DatabaseType.offline:
        return _loginOffline(username, password);

      case DatabaseType.online:
        return _loginOnline(username, password);

      case DatabaseType.hybrid:
        return _loginHybrid(username, password);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Offline: SQLite + BCrypt
  // ═══════════════════════════════════════════════════════════

  /// تسجيل الدخول أوفلاين عبر SQLite مع التحقق بـ BCrypt
  Future<Either<Failure, Map<String, dynamic>>> _loginOffline(
    String username,
    String password,
  ) async {
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

      // 1. التحقق بـ BCrypt hash (لو موجود)
      if (storedHash != null && storedHash.isNotEmpty) {
        isValid = PasswordHasher.verifyPassword(cleanPassword, storedHash);
      }
      // 2. الرجوع لـ plaintext (Lazy Migration scenario)
      if (!isValid && storedPlain != null && storedPlain.isNotEmpty) {
        isValid = PasswordHasher.verifyPassword(cleanPassword, storedPlain);
      }

      if (!isValid) {
        return const Left(Failure(401, 'كلمة المرور غير صحيحة'));
      }

      // 3. Lazy Migration: تشفير كلمة المرور بـ BCrypt لو مش موجودة
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

  // ═══════════════════════════════════════════════════════════
  // Online: Supabase Auth (username → email → signIn)
  // ═══════════════════════════════════════════════════════════

  /// تسجيل الدخول أونلاين عبر Supabase Auth
  ///
  /// الخطوات:
  /// 1. [AuthService.signInWithUsername] يجلب email من public.users ثم يُصادق
  /// 2. بناء userMap من SQLite المحلي (لو موجود) أو من بيانات Supabase
  Future<Either<Failure, Map<String, dynamic>>> _loginOnline(
    String username,
    String password,
  ) async {
    try {
      AppLogger.info('[AuthRepo Online]: جاري المصادقة السحابية للمستخدم: $username');

      // 1. المصادقة عبر Supabase
      final authResponse = await _authService.signInWithUsername(
        username: username,
        password: password,
      );

      final supabaseUser = authResponse.user;
      if (supabaseUser == null) {
        return const Left(Failure(401, 'فشل تسجيل الدخول السحابي — لم يُعاد بيانات المستخدم'));
      }

      // 2. محاولة جلب بيانات المستخدم الكاملة من SQLite المحلي (الأسرع والأكمل)
      final db = await DatabaseHelper.instance.database;
      final localResult = await db.query(
        'users',
        where: 'username = ? AND is_active = 1',
        whereArgs: [username.trim()],
      );

      if (localResult.isNotEmpty) {
        // المستخدم موجود محلياً — نستخدم بياناته الكاملة
        final userMap = Map<String, dynamic>.from(localResult.first);
        userMap['supabase_uid'] = supabaseUser.id;
        userMap['is_online_mode'] = true;
        AppLogger.info('[AuthRepo Online]: تم تسجيل الدخول السحابي بنجاح (بيانات SQLite).');
        return Right(userMap);
      }

      // 3. لو مش موجود محلياً — نبني userMap من بيانات Supabase
      final userMap = _buildUserMapFromSupabase(supabaseUser, username);
      AppLogger.info('[AuthRepo Online]: تم تسجيل الدخول السحابي بنجاح (بيانات Supabase).');
      return Right(userMap);
    } on Exception catch (e) {
      final message = e.toString().replaceAll('Exception: ', '');
      AppLogger.error('[AuthRepo Online]: فشل تسجيل الدخول السحابي: $e');
      return Left(Failure(401, message));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Hybrid: SQLite + تفعيل SyncService
  // ═══════════════════════════════════════════════════════════

  /// تسجيل الدخول الهجين: SQLite للمصادقة + تفعيل المزامنة السحابية
  ///
  /// ملاحظات الوضع الهجين:
  /// - المصادقة تعمل offline عبر SQLite (لا تحتاج إنترنت)
  /// - setSyncEnabled(true) يُفعَّل دائماً بعد نجاح تسجيل الدخول
  /// - على Windows: ConnectivityListener معطَّل — يعتمد على Periodic Timer كل 30 ثانية
  /// - لو النت مقطوع: syncAll() يفشل بصمت والـ sync_queue يتراكم pending
  /// - عند عودة النت (أو بعد 30s): SyncService يُزامن تلقائياً
  Future<Either<Failure, Map<String, dynamic>>> _loginHybrid(
    String username,
    String password,
  ) async {
    // 1. تسجيل الدخول عبر SQLite أولاً (لا يحتاج إنترنت)
    final result = await _loginOffline(username, password);

    // 2. لو نجح — فعّل المزامنة السحابية
    result.fold(
      (_) {},
      (userMap) {
        AppLogger.info('[AuthRepo Hybrid]: تم تسجيل الدخول محلياً. جاري تفعيل SyncService...');
        SyncService.instance.setSyncEnabled(true);
      },
    );

    return result;
  }

  // ═══════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════

  /// بناء userMap من بيانات مستخدم Supabase (fallback لو مش موجود في SQLite)
  Map<String, dynamic> _buildUserMapFromSupabase(dynamic supabaseUser, String username) {
    final now = DateTime.now().toIso8601String();
    return {
      'id': null,
      'username': username,
      'full_name': supabaseUser.email ?? username,
      'role': 'secretary',
      'clinic_id': 1,
      'permissions_json': '[]',
      'is_active': 1,
      'supabase_uid': supabaseUser.id,
      'is_online_mode': true,
      'created_at': now,
      'updated_at': now,
    };
  }
}
