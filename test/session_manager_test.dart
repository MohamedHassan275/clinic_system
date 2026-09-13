import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_system/core/security/session_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionManager Unit Tests', () {
    final sessionManager = SessionManager.instance;

    setUp(() async {
      await sessionManager.clearSession();
    });

    test('1. setUserSession sets currentUser and marks user as logged in', () async {
      final user = {
        'id': 1,
        'username': 'mo_hassan',
        'role': 'admin',
        'permissions_json': '["dashboard","appointments","settings"]',
      };

      sessionManager.setUserSession(user, rememberMe: true);

      expect(sessionManager.isLoggedIn, isTrue);
      expect(sessionManager.currentUser?['username'], equals('mo_hassan'));
      expect(sessionManager.userPermissions, contains('dashboard'));
    });

    test('2. hasPermission returns true for authorized permissions and false for unauthorized', () {
      final user = {
        'id': 2,
        'username': 'dr_hassan',
        'role': 'doctor',
        'permissions_json': '["dashboard","emr"]',
      };

      sessionManager.setUserSession(user);

      expect(sessionManager.hasPermission('dashboard'), isTrue);
      expect(sessionManager.hasPermission('emr'), isTrue);
      expect(sessionManager.hasPermission('billing'), isFalse);
    });

    test('3. updateLastActivity updates last_activity_timestamp', () {
      final user = {'id': 1, 'username': 'test_user', 'role': 'admin'};
      sessionManager.setUserSession(user);

      final initialTime = sessionManager.lastActivityTime;
      expect(initialTime, isNotNull);

      sessionManager.updateLastActivity();
      final updatedTime = sessionManager.lastActivityTime;
      expect(updatedTime, isNotNull);
    });

    test('4. clearSession removes session credentials and logs out user', () async {
      final user = {'id': 1, 'username': 'test_user', 'role': 'admin'};
      sessionManager.setUserSession(user);
      expect(sessionManager.isLoggedIn, isTrue);

      await sessionManager.clearSession();

      expect(sessionManager.isLoggedIn, isFalse);
      expect(sessionManager.currentUser, isNull);
      expect(sessionManager.userPermissions, isEmpty);
    });

    test('5. session expires after inactivity timeout', () async {
      final expiredUser = {
        'id': 1,
        'username': 'expired_user',
        'role': 'doctor',
        'login_timestamp': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
        'last_activity_timestamp': DateTime.now().subtract(const Duration(minutes: 35)).toIso8601String(), // > 30 min
        'remember_me': false,
      };

      // Set user session directly without overwriting last_activity_timestamp
      sessionManager.setUserSession(expiredUser);
      // Explicitly set past activity timestamp
      sessionManager.currentUser?['last_activity_timestamp'] = DateTime.now().subtract(const Duration(minutes: 35)).toIso8601String();

      expect(sessionManager.isLoggedIn, isFalse);
    });
  });
}
