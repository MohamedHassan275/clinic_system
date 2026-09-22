import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_system/core/config/supabase_config.dart';
import 'package:clinic_system/core/auth/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 1 - Supabase Connection & Auth Unit Tests', () {
    test('1. SupabaseConfig holds valid URL and anonKey', () {
      expect(SupabaseConfig.url, equals('https://gmmyvbocbtmuxzwaqzqj.supabase.co'));
      expect(SupabaseConfig.anonKey, isNotEmpty);
      expect(SupabaseConfig.url.startsWith('https://'), isTrue);
      expect(SupabaseConfig.url.endsWith('/rest/v1/'), isFalse);
    });

    test('2. AuthService instance initializes correctly', () {
      final authService = AuthService();
      expect(authService, isNotNull);
      expect(authService.currentUser, isNull);
      expect(authService.currentSession, isNull);
    });
  });
}
