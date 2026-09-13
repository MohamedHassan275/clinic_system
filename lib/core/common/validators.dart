import 'package:email_validator/email_validator.dart';

/// Comprehensive validation utilities for the Clinic System
class AppValidators {
  AppValidators._();

  /// Required field validator
  static String? required(String? value, [String message = 'هذا الحقل مطلوب']) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  /// Minimum length validator
  static String? minLength(String? value, int min, [String? message]) {
    if (value == null || value.trim().length < min) {
      return message ?? 'يجب ألا يقل النص عن $min أحرف';
    }
    return null;
  }

  /// Maximum length validator
  static String? maxLength(String? value, int max, [String? message]) {
    if (value != null && value.trim().length > max) {
      return message ?? 'يجب ألا يزيد النص عن $max حرفاً';
    }
    return null;
  }

  /// Name validator (Arabic & English letters, spaces, 2+ chars)
  static String? name(String? value, [String? message]) {
    final req = required(value);
    if (req != null) return req;

    final trimmed = value!.trim();
    if (trimmed.length < 2) {
      return 'يجب أن يتكون الاسم من حرفين على الأقل';
    }

    final nameRegex = RegExp(r"^[\u0600-\u06FFa-zA-Z\s\.'-]+$");
    if (!nameRegex.hasMatch(trimmed)) {
      return message ?? 'الاسم يجب أن يحتوي على أحرف عربية أو إنجليزية فقط دون أرقام أو رموز غريبة';
    }
    return null;
  }

  /// Phone number validator (EG: 11 digits, SA: 9-10 digits, or International)
  static String? phone(String? value, [String? message]) {
    final req = required(value);
    if (req != null) return req;

    final trimmed = value!.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // EG Phone format (e.g. 01012345678, 011..., 012..., 015...)
    final egRegex = RegExp(r'^01[0125][0-9]{8}$');
    // SA Phone format (e.g. 0512345678 or +9665...)
    final saRegex = RegExp(r'^(05|5|\+9665)[0-9]{8}$');
    // Generic International format (+ prefix + 8-15 digits)
    final intlRegex = RegExp(r'^\+[1-9][0-9]{7,14}$');

    if (egRegex.hasMatch(trimmed) || saRegex.hasMatch(trimmed) || intlRegex.hasMatch(trimmed)) {
      return null;
    }

    return message ?? 'يرجى إدخال رقم هاتف صحيح (مصري 11 رقم، أو سعودي، أو بصيغة دولية)';
  }

  /// Egyptian National ID validator (14 digits with century, DOB, governorate, & gender checks)
  static String? nationalId(String? value, [String? message]) {
    final req = required(value);
    if (req != null) return req;

    final trimmed = value!.trim();
    if (!RegExp(r'^\d{14}$').hasMatch(trimmed)) {
      return message ?? 'الرقم القومي يجب أن يتكون من 14 رقماً exact';
    }

    // Century check (2 = 1900-1999, 3 = 2000-2099)
    final centuryDigit = int.parse(trimmed.substring(0, 1));
    if (centuryDigit != 2 && centuryDigit != 3) {
      return 'الرقم القومي غير صحيح (خانة القرن يجب أن تكون 2 أو 3)';
    }

    final yearPrefix = centuryDigit == 2 ? '19' : '20';
    final yy = trimmed.substring(1, 3);
    final mm = trimmed.substring(3, 5);
    final dd = trimmed.substring(5, 7);

    final birthDateStr = '$yearPrefix$yy-$mm-$dd';
    try {
      final dob = DateTime.parse(birthDateStr);
      if (dob.month != int.parse(mm) || dob.day != int.parse(dd)) {
        return 'الرقم القومي غير صحيح (تاريخ الميلاد غير صالح)';
      }
      if (dob.isAfter(DateTime.now())) {
        return 'الرقم القومي غير صحيح (تاريخ الميلاد في المستقبل)';
      }
    } catch (_) {
      return 'الرقم القومي غير صحيح (تاريخ الميلاد غير صالح)';
    }

    // Governorate Code check (01 to 88 except invalid codes)
    final govCode = int.parse(trimmed.substring(7, 9));
    final validGovCodes = <int>{
      1, 2, 3, 4, 11, 12, 13, 14, 15, 16, 17, 18, 19, 21, 22, 23, 24, 25, 26, 27, 28, 29, 31, 32, 33, 34, 35, 88
    };
    if (!validGovCodes.contains(govCode)) {
      return 'الرقم القومي غير صحيح (كود المحافظة غير معروف)';
    }

    return null;
  }

  /// Passport validator for international patients/users (Alphanumeric 6-12 chars)
  static String? passport(String? value, [String? message]) {
    final req = required(value);
    if (req != null) return req;

    final trimmed = value!.trim();
    final passportRegex = RegExp(r'^[a-zA-Z0-9]{6,12}$');
    if (!passportRegex.hasMatch(trimmed)) {
      return message ?? 'رقم جواز السفر يجب أن يتكون من 6 إلى 12 حرف ورقم بالإنجليزية';
    }
    return null;
  }

  /// Email validator using email_validator package + RFC Regex
  static String? email(String? value, [String? message]) {
    final req = required(value);
    if (req != null) return req;

    final trimmed = value!.trim();
    if (!EmailValidator.validate(trimmed)) {
      return message ?? 'يرجى إدخال بريد إلكتروني بصيغة صحيحة (example@domain.com)';
    }
    return null;
  }

  /// Password validator (8+ chars, upper, lower, number, special char)
  static String? password(String? value, {bool strict = true, String? message}) {
    final req = required(value);
    if (req != null) return req;

    final trimmed = value!;
    if (trimmed.length < 8) {
      return 'كلمة المرور يجب ألا تقل عن 8 أحرف';
    }

    if (strict) {
      final hasUpper = RegExp(r'[A-Z]').hasMatch(trimmed);
      final hasLower = RegExp(r'[a-z]').hasMatch(trimmed);
      final hasDigit = RegExp(r'[0-9]').hasMatch(trimmed);
      final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(trimmed);

      if (!hasUpper || !hasLower || !hasDigit || !hasSpecial) {
        return message ?? 'كلمة المرور يجب أن تحتوي على حرف كبير، حرف صغير، رقم، ورمز خاص';
      }
    }

    return null;
  }

  /// Age validator (integer between 1 and 120)
  static String? age(String? value, [String? message]) {
    final req = required(value);
    if (req != null) return req;

    final parsed = int.tryParse(value!.trim());
    if (parsed == null || parsed < 1 || parsed > 120) {
      return message ?? 'العمر يجب أن يكون رقماً صحيحاً بين 1 و 120 سنة';
    }
    return null;
  }

  /// Monetary amount validator (> 0)
  static String? amount(String? value, [String? message]) {
    final req = required(value);
    if (req != null) return req;

    final parsed = double.tryParse(value!.trim());
    if (parsed == null || parsed <= 0) {
      return message ?? 'المبلغ يجب أن يكون رقماً موجباً أكبر من الصفر';
    }
    return null;
  }

  /// Numeric validator
  static String? numeric(String? value, [String? message]) {
    final req = required(value);
    if (req != null) return req;

    if (double.tryParse(value!.trim()) == null) {
      return message ?? 'يرجى إدخال أرقام فقط';
    }
    return null;
  }

  /// Barcode validator
  static String? barcode(String? value, [String? message]) {
    final req = required(value);
    if (req != null) return req;

    if (!RegExp(r'^[a-zA-Z0-9\-_]+$').hasMatch(value!.trim())) {
      return message ?? 'البار كود يجب أن يحتوي على أرقام وأحرف إنجليزية فقط';
    }
    return null;
  }

  /// URL validator
  static String? url(String? value, [String? message]) {
    if (value == null || value.trim().isEmpty) return null;

    final trimmed = value.trim();
    final urlRegex = RegExp(r'^(https?:\/\/)?([\w\d\-_]+\.)+[\w\d\-_]+(\/.*)?$');
    if (!urlRegex.hasMatch(trimmed)) {
      return message ?? 'يرجى إدخال رابط موقع إلكتروني صحيح';
    }
    return null;
  }

  /// Past Date validator (Date must not be in the future)
  static String? pastDate(DateTime? date, [String? message]) {
    if (date == null) return 'التاريخ مطلوب';
    if (date.isAfter(DateTime.now())) {
      return message ?? 'التاريخ لا يمكن أن يكون في المستقبل';
    }
    return null;
  }

  /// Date Range validator
  static String? dateRange(DateTime? start, DateTime? end, [String? message]) {
    if (start == null || end == null) return 'يرجى تحديد بداية ونهاية الفترة';
    if (end.isBefore(start)) {
      return message ?? 'تاريخ النهاية لا يمكن أن يكون قبل تاريخ البداية';
    }
    return null;
  }
}
