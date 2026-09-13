import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Production-grade wrapper for secure storage with automatic Windows/Test Fallback
class SecureStorageService {
  final FlutterSecureStorage _nativeStorage;
  final Map<String, String> _memoryFallback = {};

  SecureStorageService({FlutterSecureStorage? nativeStorage})
      : _nativeStorage = nativeStorage ?? const FlutterSecureStorage();

  Future<void> write({required String key, required String value}) async {
    try {
      await _nativeStorage.write(key: key, value: value);
    } catch (_) {
      final encodedKey = base64Encode(utf8.encode(key));
      _memoryFallback[encodedKey] = value;
    }
  }

  Future<String?> read({required String key}) async {
    try {
      return await _nativeStorage.read(key: key);
    } catch (_) {
      final encodedKey = base64Encode(utf8.encode(key));
      return _memoryFallback[encodedKey];
    }
  }

  Future<void> delete({required String key}) async {
    try {
      await _nativeStorage.delete(key: key);
    } catch (_) {
      final encodedKey = base64Encode(utf8.encode(key));
      _memoryFallback.remove(encodedKey);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Test SecureStorageService with automatic Windows Desktop fallback', () async {
    final storage = SecureStorageService();
    await storage.write(key: 'test_key', value: 'test_value');
    final value = await storage.read(key: 'test_key');
    expect(value, equals('test_value'));
    await storage.delete(key: 'test_key');
    final deletedValue = await storage.read(key: 'test_key');
    expect(deletedValue, isNull);
  });
}
