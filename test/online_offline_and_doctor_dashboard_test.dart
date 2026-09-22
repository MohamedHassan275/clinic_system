import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_system/core/security/session_manager.dart';
import 'package:clinic_system/modules/auth/view/login_view_model.dart';
import 'package:clinic_system/modules/auth/data/cubit/auth_cubit.dart';
import 'package:clinic_system/modules/auth/data/repo/auth_repo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Online / Offline Mode & Session Tests', () {
    final sessionManager = SessionManager.instance;

    setUp(() async {
      await sessionManager.clearSession();
      sessionManager.setOnlineMode(false);
    });

    test('1. Default session mode is Offline (isOnlineMode == false)', () {
      expect(sessionManager.isOnlineMode, isFalse);
    });

    test('2. Toggling Online mode updates SessionManager', () {
      sessionManager.setOnlineMode(true);
      expect(sessionManager.isOnlineMode, isTrue);

      sessionManager.setOnlineMode(false);
      expect(sessionManager.isOnlineMode, isFalse);
    });

    test('3. LoginViewModel initializes with default Offline mode and toggles state correctly', () {
      final authCubit = AuthCubit(AuthRepoImpl());
      final viewModel = LoginViewModel(() {}, authCubit);
      expect(viewModel.isOnlineMode, isFalse);

      viewModel.toggleOnlineMode(true);
      expect(viewModel.isOnlineMode, isTrue);
      expect(sessionManager.isOnlineMode, isTrue);

      viewModel.toggleOnlineMode(false);
      expect(viewModel.isOnlineMode, isFalse);
      expect(sessionManager.isOnlineMode, isFalse);
    });
  });
}
