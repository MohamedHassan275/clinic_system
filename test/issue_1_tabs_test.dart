import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_system/core/enums/user_role.dart';
import 'package:clinic_system/core/security/session_manager.dart';
import 'package:clinic_system/modules/main_shell/view/main_shell_view_model.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    SessionManager.instance.setUserSession({
      'id': 1,
      'username': 'admin',
      'full_name': 'مدير النظام',
      'role': 'super_admin',
      'permissions_json': '[]',
    });
  });

  group('Issue 1: MainShell Portal Tabs Unit Tests', () {
    test('1. Toggling admin role view switches activeRoleMode and resets selectedIndex immediately', () {
      bool reloaded = false;
      final viewModel = MainShellViewModel(() {
        reloaded = true;
      });
      viewModel.updateRefresh(() => reloaded = true);
      viewModel.addListener(() => reloaded = true);

      expect(viewModel.activeRoleMode, equals(UserRole.doctor));
      expect(viewModel.selectedIndex, equals(0));
      expect(viewModel.allowedMenuItems.first.key, equals('dashboard'));

      viewModel.toggleAdminRoleView(UserRole.secretary);

      expect(reloaded, isTrue);
      expect(viewModel.activeRoleMode, equals(UserRole.secretary));
      expect(viewModel.selectedIndex, equals(0));
      expect(viewModel.allowedMenuItems.first.key, equals('reception'));

      reloaded = false;
      viewModel.toggleAdminRoleView(UserRole.doctor);

      expect(reloaded, isTrue);
      expect(viewModel.activeRoleMode, equals(UserRole.doctor));
      expect(viewModel.selectedIndex, equals(0));
      expect(viewModel.allowedMenuItems.first.key, equals('dashboard'));
    });
  });
}
