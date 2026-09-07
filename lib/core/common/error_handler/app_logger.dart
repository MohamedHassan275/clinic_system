import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static void log(String message) {
    if (kDebugMode) {
      debugPrint('💡 [CLINIC_LOG]: $message');
    }
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('🔴 [CLINIC_ERROR]: $message ${error ?? ""}');
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }
  }

  static void info(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ [CLINIC_INFO]: $message');
    }
  }
}
