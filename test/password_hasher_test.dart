import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_system/core/security/password_hasher.dart';

void main() {
  group('PasswordHasher Unit Tests', () {
    test('1. hashPassword generates a valid BCrypt hash string', () {
      final hash = PasswordHasher.hashPassword('MySecurePassword123!');
      expect(hash, isNotEmpty);
      expect(PasswordHasher.isBcryptHash(hash), isTrue);
    });

    test('2. verifyPassword returns true for correct password', () {
      const password = 'CorrectPassword456#';
      final hash = PasswordHasher.hashPassword(password);
      final isValid = PasswordHasher.verifyPassword(password, hash);
      expect(isValid, isTrue);
    });

    test('3. verifyPassword returns false for wrong password', () {
      const password = 'CorrectPassword456#';
      final hash = PasswordHasher.hashPassword(password);
      final isValid = PasswordHasher.verifyPassword('WrongPassword123', hash);
      expect(isValid, isFalse);
    });

    test('4. verifyPassword handles empty inputs safely', () {
      final isValidEmptyPass = PasswordHasher.verifyPassword('', '\$2a\$10\$someHashString');
      final isValidEmptyHash = PasswordHasher.verifyPassword('password', '');
      expect(isValidEmptyPass, isFalse);
      expect(isValidEmptyHash, isFalse);
    });

    test('5. isBcryptHash correctly identifies BCrypt format prefixes', () {
      expect(PasswordHasher.isBcryptHash('\$2a\$10\$abcdefghijklmnopqrstuv'), isTrue);
      expect(PasswordHasher.isBcryptHash('\$2b\$10\$abcdefghijklmnopqrstuv'), isTrue);
      expect(PasswordHasher.isBcryptHash('\$2y\$10\$abcdefghijklmnopqrstuv'), isTrue);
      expect(PasswordHasher.isBcryptHash('plain_password_string'), isFalse);
      expect(PasswordHasher.isBcryptHash('123456'), isFalse);
    });
  });
}
