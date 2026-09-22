import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_system/core/sync/sync_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('SyncService Unit Tests', () {
    test('1. SyncService singleton instance initializes with offline status', () {
      final service = SyncService.instance;
      expect(service, isNotNull);
      expect(service.status, equals(SyncStatus.offline));
      expect(service.isSyncEnabled, isTrue);
    });

    test('2. setSyncEnabled updates sync enable toggle state', () {
      final service = SyncService.instance;

      service.setSyncEnabled(false);
      expect(service.isSyncEnabled, isFalse);
      expect(service.status, equals(SyncStatus.offline));

      service.setSyncEnabled(true);
      expect(service.isSyncEnabled, isTrue);
    });
  });
}
