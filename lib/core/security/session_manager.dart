import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../common/error_handler/app_logger.dart';
import '../database/database_helper.dart';

class SessionManager {
  static final SessionManager instance = SessionManager._init();

  SessionManager._init();

  Map<String, dynamic>? _currentUser;
  List<String> _userPermissions = [];
  Map<String, dynamic>? _activeShift;

  Map<String, dynamic>? get currentUser => _currentUser;
  List<String> get userPermissions => List.unmodifiable(_userPermissions);
  Map<String, dynamic>? get activeShift => _activeShift;
  bool get hasActiveShift => _activeShift != null && (_activeShift!['is_closed'] == 0);
  bool get isLoggedIn => _currentUser != null;

  Future<File> _getSessionFile() async {
    final Directory docDir = await getApplicationDocumentsDirectory();
    final String path = join(docDir.path, 'clinic_active_session.json');
    return File(path);
  }

  /// Initializes persistent session from disk on app startup
  Future<void> initPersistentSession() async {
    try {
      final file = await _getSessionFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final Map<String, dynamic> user = jsonDecode(content);
          _currentUser = user;
          _parsePermissions(user);
          AppLogger.info('Restored persistent session for user: ${user['username']}');

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
      }
    } catch (e) {
      AppLogger.error('Failed to restore persistent user session', e);
    }
  }

  void setUserSession(Map<String, dynamic> user) {
    _currentUser = Map<String, dynamic>.from(user);
    _parsePermissions(user);
    _persistSessionToDisk(user);
    AppLogger.info('User session updated for: ${_currentUser!['username']} with permissions: $_userPermissions');
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

  Future<void> _persistSessionToDisk(Map<String, dynamic> user) async {
    try {
      final file = await _getSessionFile();
      await file.writeAsString(jsonEncode(user));
    } catch (e) {
      AppLogger.error('Failed to persist user session to disk', e);
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

  void clearSession() async {
    AppLogger.info('Clearing user session');
    _currentUser = null;
    _userPermissions = [];
    _activeShift = null;
    try {
      final file = await _getSessionFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      AppLogger.error('Failed to delete persistent session file', e);
    }
  }
}
