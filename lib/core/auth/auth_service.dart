import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// خدمة المصادقة السحابية باستخدام Supabase Auth
class AuthService {
  /// الحصول على العميل التابع لـ Supabase
  SupabaseClient get _client => Supabase.instance.client;

  /// تسجيل الدخول باستعمال البريد الإلكتروني وكلمة المرور
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('⚡ [AuthService]: Attempting signIn for email: $email');
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      debugPrint('✅ [AuthService]: SignIn successful. User ID: ${response.user?.id}');
      return response;
    } on AuthException catch (e) {
      debugPrint('🔴 [AuthService AuthException]: ${e.message} (Code: ${e.statusCode})');
      rethrow;
    } catch (e) {
      debugPrint('🔴 [AuthService Error]: Failed to sign in: $e');
      rethrow;
    }
  }

  /// تسجيل الدخول باستخدام اسم المستخدم وكلمة المرور
  ///
  /// الآلية:
  /// 1. جلب البريد الإلكتروني من جدول public.users باستخدام username
  /// 2. التحقق من حالة الحساب (is_active)
  /// 3. تسجيل الدخول باستخدام email + password عبر Supabase Auth
  Future<AuthResponse> signInWithUsername({
    required String username,
    required String password,
  }) async {
    try {
      final cleanUsername = username.trim();
      debugPrint('⚡ [AuthService]: جاري جلب البريد الإلكتروني للمستخدم: $cleanUsername');

      String? email;

      // 1. محاولة استخدام RPC get_email_by_username (متوافق مع RLS SECURITY DEFINER)
      try {
        final rpcRes = await _client.rpc(
          'get_email_by_username',
          params: {'p_username': cleanUsername},
        );
        if (rpcRes != null && rpcRes is String && rpcRes.isNotEmpty) {
          email = rpcRes;
        }
      } catch (e) {
        debugPrint('ℹ️ [AuthService RPC Notice]: RPC get_email_by_username fallback: $e');
      }

      // 2. إذا لم يرجع الـ RPC بريداً، جرب الاستعلام المباشر من public.users (في حال RLS معطل)
      if (email == null || email.isEmpty) {
        final res = await _client
            .from('users')
            .select('email, is_active')
            .eq('username', cleanUsername)
            .maybeSingle();

        if (res == null) {
          throw const AuthException('اسم المستخدم غير موجود في النظام السحابي');
        }

        final isActive = res['is_active'];
        final bool accountActive = isActive == true || isActive == 1;
        if (!accountActive) {
          throw const AuthException('الحساب معطل — تواصل مع مسؤول النظام');
        }

        email = res['email'] as String?;
      }

      if (email == null || email.isEmpty) {
        throw const AuthException('لا يوجد بريد إلكتروني مرتبط بهذا الحساب');
      }

      debugPrint('✅ [AuthService]: تم العثور على البريد الإلكتروني ($email). جاري المصادقة...');

      // 3. تسجيل الدخول باستخدام email + password
      return await signIn(email: email, password: password);
    } on AuthException {
      rethrow;
    } catch (e) {
      debugPrint('🔴 [AuthService Error]: فشل تسجيل الدخول بـ username: $e');
      throw AuthException('فشل الاتصال بالخادم السحابي: $e');
    }
  }

  /// تسجيل الخروج وإلغاء الجلسة السحابية الحالية
  Future<void> signOut() async {
    try {
      debugPrint('⚡ [AuthService]: Signing out active session...');
      await _client.auth.signOut();
      debugPrint('✅ [AuthService]: Signed out successfully.');
    } catch (e) {
      debugPrint('🔴 [AuthService Error]: Failed to sign out: $e');
      rethrow;
    }
  }

  /// الحصول على بيانات المستخدم السحابي الحالي (User)
  User? get currentUser {
    try {
      return _client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// الحصول على الجلسة السحابية الحالية (Session)
  Session? get currentSession {
    try {
      return _client.auth.currentSession;
    } catch (_) {
      return null;
    }
  }
}
