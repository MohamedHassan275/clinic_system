import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  /// Formats date string to yyyy-MM-dd (e.g. 2026-09-15)
  static String formatDate(String? dateStr, {String fallback = '-'}) {
    if (dateStr == null || dateStr.trim().isEmpty || dateStr == 'غير محدد' || dateStr == 'غير مسجل') {
      return fallback;
    }
    final raw = dateStr.trim();
    try {
      final date = DateTime.parse(raw);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (_) {
      if (raw.contains('T')) return raw.split('T').first;
      if (raw.contains(' ')) return raw.split(' ').first;
      if (raw.length >= 10) return raw.substring(0, 10);
      return fallback;
    }
  }

  /// Formats date and time string to yyyy-MM-dd HH:mm (e.g. 2026-09-15 14:06)
  static String formatDateTime(String? dateStr, {String fallback = '-'}) {
    if (dateStr == null || dateStr.trim().isEmpty || dateStr == 'غير محدد' || dateStr == 'غير مسجل') {
      return fallback;
    }
    try {
      final date = DateTime.parse(dateStr.trim());
      return DateFormat('yyyy-MM-dd HH:mm').format(date);
    } catch (_) {
      return fallback;
    }
  }

  /// Formats date to Arabic localized format (e.g. 15 سبتمبر 2026)
  static String formatArabic(String? dateStr, {String fallback = '-'}) {
    if (dateStr == null || dateStr.trim().isEmpty || dateStr == 'غير محدد' || dateStr == 'غير مسجل') {
      return fallback;
    }
    try {
      final date = DateTime.parse(dateStr.trim());
      return DateFormat('d MMMM yyyy', 'ar').format(date);
    } catch (_) {
      return fallback;
    }
  }

  /// Formats time string to HH:mm (e.g. 14:06)
  static String formatTime(String? dateStr, {String fallback = '-'}) {
    if (dateStr == null || dateStr.trim().isEmpty || dateStr == 'غير محدد' || dateStr == 'غير مسجل') {
      return fallback;
    }
    try {
      final date = DateTime.parse(dateStr.trim());
      return DateFormat('HH:mm').format(date);
    } catch (_) {
      return fallback;
    }
  }
}
