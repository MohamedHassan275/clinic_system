import 'package:flutter_test/flutter_test.dart';
import 'package:bcrypt/bcrypt.dart';

void main() {
  test('Test bcrypt hashing and checkpw on Windows', () {
    final hash = BCrypt.hashpw('test123', BCrypt.gensalt());
    final ok = BCrypt.checkpw('test123', hash);
    expect(ok, isTrue);
  });
}
