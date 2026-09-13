import 'package:bcrypt/bcrypt.dart';
import '../common/error_handler/app_logger.dart';

/// Password Hashing service utilizing BCrypt for secure password storage and verification
class PasswordHasher {
  PasswordHasher._();

  /// Default work factor / rounds for BCrypt
  static const int _costRounds = 10;

  /// Hash a plaintext password using BCrypt with embedded salt
  static String hashPassword(String plainPassword) {
    try {
      final salt = BCrypt.gensalt(logRounds: _costRounds);
      return BCrypt.hashpw(plainPassword, salt);
    } catch (e) {
      AppLogger.error('Failed to hash password with BCrypt', e);
      rethrow;
    }
  }

  /// Verify a plaintext password against a stored BCrypt hash
  static bool verifyPassword(String plainPassword, String hashedPassword) {
    try {
      if (plainPassword.isEmpty || hashedPassword.isEmpty) return false;
      
      // If the stored string is not a valid BCrypt hash, fallback to direct comparison for Lazy Migration
      if (!isBcryptHash(hashedPassword)) {
        return plainPassword == hashedPassword;
      }
      
      return BCrypt.checkpw(plainPassword, hashedPassword);
    } catch (e) {
      AppLogger.error('Failed to verify password with BCrypt', e);
      return false;
    }
  }

  /// Helper to check if a string matches BCrypt hash format ($2a$, $2b$, or $2y$)
  static bool isBcryptHash(String hash) {
    return hash.startsWith(r'$2a$') || hash.startsWith(r'$2b$') || hash.startsWith(r'$2y$');
  }
}
