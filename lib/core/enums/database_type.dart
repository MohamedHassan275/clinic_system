/// أنواع قواعد البيانات المدعومة في نظام المصادقة والمزامنة
enum DatabaseType {
  /// وضع بدون إنترنت — يعمل على SQLite المحلي فقط
  offline,

  /// وضع الإنترنت — يعمل على Supabase Auth + public.users
  online,

  /// وضع هجين — يعمل على SQLite ويفعّل المزامنة السحابية تلقائياً
  hybrid;

  /// الاسم المعروض للمستخدم
  String get displayName {
    switch (this) {
      case DatabaseType.offline:
        return 'Offline';
      case DatabaseType.online:
        return 'Online';
      case DatabaseType.hybrid:
        return 'Hybrid';
    }
  }

  /// الوصف التفصيلي للمستخدم
  String get description {
    switch (this) {
      case DatabaseType.offline:
        return 'العمل السريع على SQLite المحلي بدون إنترنت';
      case DatabaseType.online:
        return 'المصادقة السحابية عبر Supabase Auth';
      case DatabaseType.hybrid:
        return 'SQLite محلي + مزامنة سحابية تلقائية';
    }
  }

  /// أيقونة كل وضع
  bool get requiresInternet => this == DatabaseType.online;

  /// هل يُفعَّل SyncService في هذا الوضع؟
  bool get enablesSync => this == DatabaseType.hybrid || this == DatabaseType.online;
}
