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
