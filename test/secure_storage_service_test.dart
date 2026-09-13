import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_system/core/security/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureStorageService Unit Tests', () {
    final storage = SecureStorageService.instance;

    test('1. write and read string key-value successfully', () async {
      await storage.write(key: 'auth_token', value: 'secret_token_12345');
      final val = await storage.read(key: 'auth_token');
      expect(val, equals('secret_token_12345'));
    });

    test('2. read non-existent key returns null', () async {
      final val = await storage.read(key: 'non_existent_key_xyz');
      expect(val, isNull);
    });

    test('3. delete key removes value from storage', () async {
      await storage.write(key: 'temp_key', value: 'temp_value');
      await storage.delete(key: 'temp_key');
      final val = await storage.read(key: 'temp_key');
      expect(val, isNull);
    });

    test('4. overwrite existing key updates value', () async {
      await storage.write(key: 'user_role', value: 'doctor');
      await storage.write(key: 'user_role', value: 'admin');
      final val = await storage.read(key: 'user_role');
      expect(val, equals('admin'));
    });

    test('5. deleteAll clears stored data', () async {
      await storage.write(key: 'k1', value: 'v1');
      await storage.write(key: 'k2', value: 'v2');
      await storage.deleteAll();
      final val1 = await storage.read(key: 'k1');
      final val2 = await storage.read(key: 'k2');
      expect(val1, isNull);
      expect(val2, isNull);
    });
  });
}
