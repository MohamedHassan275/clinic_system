import 'dart:convert';
import '../common/error_handler/app_logger.dart';
import '../database/database_helper.dart';
import 'secure_storage_service.dart';

/// Secure Session Manager providing encrypted session storage,
/// strict 30-minute inactivity timeout, 12-hour shift limit, and optional 30-day Remember Me.
class SessionManager {
  static final SessionManager instance = SessionManager._init();

  SessionManager._init();

  static const String _sessionKey = 'active_clinic_user_session';
  
  /// Inactivity timeout: 30 minutes
  static const Duration defaultInactivityTimeout = Duration(minutes: 30);
  /// Absolute shift session timeout: 12 hours
  static const Duration absoluteSessionTimeout = Duration(hours: 12);
  /// Remember Me session timeout: 30 days
  static const Duration rememberMeSessionTimeout = Duration(days: 30);

  Map<String, dynamic>? _currentUser;
  List<String> _userPermissions = [];
  Map<String, dynamic>? _activeShift;
  DateTime? _lastActivityTime;

  Map<String, dynamic>? get currentUser => _currentUser;
  List<String> get userPermissions => List.unmodifiable(_userPermissions);
  Map<String, dynamic>? get activeShift => _activeShift;
  bool get hasActiveShift => _activeShift != null && (_activeShift!['is_closed'] == 0);
  bool get isLoggedIn => _currentUser != null && !_isSessionExpired();
  DateTime? get lastActivityTime => _lastActivityTime;

  /// Initializes persistent encrypted session from SecureStorageService on app startup
  Future<void> initPersistentSession() async {
    try {
      final sessionJson = await SecureStorageService.instance.read(key: _sessionKey);
      if (sessionJson != null && sessionJson.isNotEmpty) {
        final Map<String, dynamic> user = jsonDecode(sessionJson);
        
        // Check if session has expired
        if (_isSessionExpiredData(user)) {
          AppLogger.info('Stored session has expired. Clearing session.');
          await clearSession();
          return;
        }

        _currentUser = user;
        _parsePermissions(user);
        _lastActivityTime = DateTime.now();
        AppLogger.info('Restored encrypted persistent session for user: ${user['username']}');

        // Check if there is an active unclosed shift in SQLite for this user
        final db = await DatabaseHelper.instance.database;
        final shiftRes = await db.query(
          'shifts',
          where: 'user_id = ? AND is_closed = 0',
          whereArgs: [user['id']],
          orderBy: 'id DESC',
          limit: 1,
        );

        if (shiftRes.isNotEmpty) {
          _activeShift = Map<String, dynamic>.from(shiftRes.first);
          AppLogger.info('Restored active shift ID: ${_activeShift!['id']}');
        }
      }
    } catch (e) {
      AppLogger.error('Failed to restore encrypted persistent user session', e);
    }
  }

  void setUserSession(Map<String, dynamic> user, {bool rememberMe = false}) {
    final sessionData = Map<String, dynamic>.from(user);
    final now = DateTime.now();
    sessionData['login_timestamp'] = now.toIso8601String();
    sessionData['last_activity_timestamp'] = now.toIso8601String();
    sessionData['remember_me'] = rememberMe;

    _currentUser = sessionData;
    _lastActivityTime = now;
    _parsePermissions(sessionData);
    _persistSessionToSecureStorage(sessionData);
    AppLogger.info('Encrypted user session updated for: ${_currentUser!['username']} (Remember Me: $rememberMe)');
  }

  /// Updates last activity timestamp to prevent 30-minute inactivity timeout
  void updateLastActivity() {
    if (_currentUser == null) return;
    final now = DateTime.now();
    _lastActivityTime = now;
    _currentUser!['last_activity_timestamp'] = now.toIso8601String();
    _persistSessionToSecureStorage(_currentUser!);
  }

  void _parsePermissions(Map<String, dynamic> user) {
    try {
      final rawPerms = user['permissions_json'];
      if (rawPerms is String) {
        final List<dynamic> list = jsonDecode(rawPerms);
        _userPermissions = list.map((e) => e.toString()).toList();
      } else if (rawPerms is List) {
        _userPermissions = rawPerms.map((e) => e.toString()).toList();
      } else {
        _userPermissions = [];
      }
    } catch (e) {
      AppLogger.error('Failed to parse user permissions_json', e);
      _userPermissions = [];
    }
  }

  Future<void> _persistSessionToSecureStorage(Map<String, dynamic> user) async {
    try {
      final jsonStr = jsonEncode(user);
      await SecureStorageService.instance.write(key: _sessionKey, value: jsonStr);
    } catch (e) {
      AppLogger.error('Failed to persist user session to encrypted secure storage', e);
    }
  }

  void setActiveShift(Map<String, dynamic>? shift) {
    if (shift != null) {
      _activeShift = Map<String, dynamic>.from(shift);
      AppLogger.info('Active shift set: Shift ID ${_activeShift!['id']}');
    } else {
      _activeShift = null;
      AppLogger.info('Active shift cleared');
    }
  }

  bool hasPermission(String permission) {
    if (!isLoggedIn) return false;
    if (_userPermissions.isNotEmpty) {
      return _userPermissions.contains(permission);
    }
    // Fallback if permissions list is empty: admin gets all permissions
    return _currentUser!['role'] == 'admin';
  }

  Future<void> clearSession() async {
    AppLogger.info('Clearing encrypted user session');
    _currentUser = null;
    _userPermissions = [];
    _activeShift = null;
    _lastActivityTime = null;
    try {
      await SecureStorageService.instance.delete(key: _sessionKey);
    } catch (e) {
      AppLogger.error('Failed to delete encrypted persistent session from secure storage', e);
    }
  }

  bool _isSessionExpired() {
    if (_currentUser == null) return true;
    return _isSessionExpiredData(_currentUser!);
  }

  bool _isSessionExpiredData(Map<String, dynamic> data) {
    try {
      final now = DateTime.now();

      // 1. Check Inactivity Timeout (Default 30 minutes)
      final lastActStr = data['last_activity_timestamp'] ?? data['login_timestamp'];
      if (lastActStr != null) {
        final lastActTime = DateTime.parse(lastActStr);
        if (now.difference(lastActTime) > defaultInactivityTimeout) {
          return true; // Expired due to 30 min inactivity
        }
      }

      // 2. Check Absolute Session Limit (12 hours vs 30 days Remember Me)
      final loginStr = data['login_timestamp'];
      if (loginStr != null) {
        final loginTime = DateTime.parse(loginStr);
        final bool rememberMe = data['remember_me'] as bool? ?? false;
        final maxDuration = rememberMe ? rememberMeSessionTimeout : absoluteSessionTimeout;
        if (now.difference(loginTime) > maxDuration) {
          return true; // Expired due to absolute limit
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }
}
