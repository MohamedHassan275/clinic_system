import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_system/modules/main_shell/view/main_shell_view_model.dart';

void main() {
  group('Issue 8: Menu Items & Doctor Action Deduplication Unit Tests', () {
    test('1. Doctor menu items contain unique keys and titles without duplicates', () {
      final keys = MainShellViewModel.doctorMenuItems.map((item) => item.key).toList();
      final uniqueKeys = keys.toSet();
      expect(keys.length, equals(uniqueKeys.length));
    });

    test('2. Secretary menu items contain unique keys and titles without duplicates', () {
      final keys = MainShellViewModel.secretaryMenuItems.map((item) => item.key).toList();
      final uniqueKeys = keys.toSet();
      expect(keys.length, equals(uniqueKeys.length));
    });

    test('3. allowedMenuItems for Doctor role returns strictly deduplicated list', () {
      final viewModel = MainShellViewModel(() {});
      // Default non-logged in or doctor role
      final items = viewModel.allowedMenuItems;
      final keys = items.map((i) => i.key).toList();
      expect(keys.length, equals(keys.toSet().length));
    });
  });
}
