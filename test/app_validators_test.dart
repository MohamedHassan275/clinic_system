import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_system/core/common/validators.dart';

void main() {
  group('AppValidators Comprehensive Unit Tests (20+ tests)', () {
    // 1. required
    test('1. required validator returns error for null or empty string', () {
      expect(AppValidators.required(null), isNotNull);
      expect(AppValidators.required(''), isNotNull);
      expect(AppValidators.required('   '), isNotNull);
      expect(AppValidators.required('Valid Text'), isNull);
    });

    // 2. minLength & maxLength
    test('2. minLength and maxLength validate string length boundaries', () {
      expect(AppValidators.minLength('ab', 3), isNotNull);
      expect(AppValidators.minLength('abc', 3), isNull);
      expect(AppValidators.maxLength('abcdef', 5), isNotNull);
      expect(AppValidators.maxLength('abc', 5), isNull);
    });

    // 3. name
    test('3. name validator accepts Arabic & English names and rejects invalid characters', () {
      expect(AppValidators.name('محمد حسن'), isNull);
      expect(AppValidators.name('Dr. Mohamed Hassan'), isNull);
      expect(AppValidators.name('m'), isNotNull); // Too short
      expect(AppValidators.name('Mohamed 123'), isNotNull); // Contains numbers
    });

    // 4. phone (EG, SA, Intl)
    test('4. phone validator accepts EG 11-digit numbers', () {
      expect(AppValidators.phone('01000000000'), isNull);
      expect(AppValidators.phone('01112345678'), isNull);
      expect(AppValidators.phone('01212345678'), isNull);
      expect(AppValidators.phone('01512345678'), isNull);
    });

    test('5. phone validator accepts SA & International numbers', () {
      expect(AppValidators.phone('0512345678'), isNull);
      expect(AppValidators.phone('+966512345678'), isNull);
      expect(AppValidators.phone('+201000000000'), isNull);
    });

    test('6. phone validator rejects invalid numbers', () {
      expect(AppValidators.phone('12345'), isNotNull);
      expect(AppValidators.phone('01300000000'), isNotNull); // Invalid EG prefix
      expect(AppValidators.phone('abcd1234567'), isNotNull);
    });

    // 5. nationalId
    test('7. nationalId validator accepts valid Egyptian 14-digit National IDs', () {
      // 29001010101234 (Century 2, DOB 1990-01-01, Gov 01)
      expect(AppValidators.nationalId('29001010101234'), isNull);
      // 30205151201234 (Century 3, DOB 2002-05-15, Gov 12)
      expect(AppValidators.nationalId('30205151201234'), isNull);
    });

    test('8. nationalId validator rejects invalid length, century, date, or governorate', () {
      expect(AppValidators.nationalId('12345'), isNotNull); // Short
      expect(AppValidators.nationalId('19001010101234'), isNotNull); // Invalid century 1
      expect(AppValidators.nationalId('29002310101234'), isNotNull); // Invalid month 23
      expect(AppValidators.nationalId('29001019901234'), isNotNull); // Invalid governorate 99
    });

    // 6. passport
    test('9. passport validator accepts valid alphanumeric passport numbers', () {
      expect(AppValidators.passport('A1234567'), isNull);
      expect(AppValidators.passport('PASS123456'), isNull);
    });

    test('10. passport validator rejects invalid passport numbers', () {
      expect(AppValidators.passport('123'), isNotNull); // Too short
      expect(AppValidators.passport('PASSPORT1234567'), isNotNull); // Too long
      expect(AppValidators.passport('A123@#45'), isNotNull); // Special symbols
    });

    // 7. email
    test('11. email validator accepts RFC compliant emails and rejects malformed ones', () {
      expect(AppValidators.email('doctor@clinic.com'), isNull);
      expect(AppValidators.email('mo.hassan@sub.domain.org'), isNull);
      expect(AppValidators.email('plainaddress'), isNotNull);
      expect(AppValidators.email('@missingusername.com'), isNotNull);
      expect(AppValidators.email('user@.com'), isNotNull);
    });

    // 8. password
    test('12. password validator validates strict password complexity rules', () {
      expect(AppValidators.password('Pass1234!', strict: true), isNull);
      expect(AppValidators.password('short', strict: true), isNotNull); // < 8 chars
      expect(AppValidators.password('alllowercase1!', strict: true), isNotNull); // No uppercase
      expect(AppValidators.password('ALLUPPERCASE1!', strict: true), isNotNull); // No lowercase
      expect(AppValidators.password('NoDigitsSpecial', strict: true), isNotNull); // No digits/symbols
    });

    test('13. password validator accepts non-strict mode for simple testing passwords', () {
      expect(AppValidators.password('12345678', strict: false), isNull);
    });

    // 9. age
    test('14. age validator validates integer between 1 and 120', () {
      expect(AppValidators.age('25'), isNull);
      expect(AppValidators.age('1'), isNull);
      expect(AppValidators.age('120'), isNull);
      expect(AppValidators.age('0'), isNotNull);
      expect(AppValidators.age('130'), isNotNull);
      expect(AppValidators.age('twenty'), isNotNull);
    });

    // 10. amount
    test('15. amount validator validates positive numbers > 0', () {
      expect(AppValidators.amount('150.50'), isNull);
      expect(AppValidators.amount('1'), isNull);
      expect(AppValidators.amount('0'), isNotNull);
      expect(AppValidators.amount('-50'), isNotNull);
      expect(AppValidators.amount('abc'), isNotNull);
    });

    // 11. numeric & barcode
    test('16. numeric and barcode validators check alphanumeric/numeric rules', () {
      expect(AppValidators.numeric('12345'), isNull);
      expect(AppValidators.numeric('123.45'), isNull);
      expect(AppValidators.numeric('abc'), isNotNull);

      expect(AppValidators.barcode('BAR123456'), isNull);
      expect(AppValidators.barcode('BAR-123_456'), isNull);
      expect(AppValidators.barcode('BAR 123!'), isNotNull);
    });

    // 12. url
    test('17. url validator accepts valid URLs', () {
      expect(AppValidators.url('https://clinic.com'), isNull);
      expect(AppValidators.url('http://sub.clinic.org/page'), isNull);
      expect(AppValidators.url('not_a_url'), isNotNull);
    });

    // 13. pastDate
    test('18. pastDate validator ensures date is not in future', () {
      final past = DateTime.now().subtract(const Duration(days: 10));
      final future = DateTime.now().add(const Duration(days: 10));

      expect(AppValidators.pastDate(past), isNull);
      expect(AppValidators.pastDate(future), isNotNull);
    });

    // 14. dateRange
    test('19. dateRange validator ensures start date is before end date', () {
      final start = DateTime(2026, 1, 1);
      final end = DateTime(2026, 1, 31);

      expect(AppValidators.dateRange(start, end), isNull);
      expect(AppValidators.dateRange(end, start), isNotNull);
    });

    test('20. dateRange validator handles null dates gracefully', () {
      expect(AppValidators.dateRange(null, DateTime.now()), isNotNull);
      expect(AppValidators.dateRange(DateTime.now(), null), isNotNull);
    });
  });
}
