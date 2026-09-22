import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../common/error_handler/app_logger.dart';

/// Supabase Cloud Synchronization & Service Manager
class SupabaseService {
  static final SupabaseService instance = SupabaseService._init();

  SupabaseService._init();

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initializes Supabase Flutter client with optional custom URL & Anon Key
  Future<void> init({String? supabaseUrl, String? anonKey}) async {
    if (_isInitialized) return;

    final url = supabaseUrl ?? 'https://xyzcompanyclinic.supabase.co';
    final key = anonKey ?? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy_anon_key';

    try {
      await Supabase.initialize(
        url: url,
        // ignore: deprecated_member_use
        anonKey: key,
      );
      _isInitialized = true;
      AppLogger.info('Supabase cloud service initialized successfully.');
    } catch (e) {
      AppLogger.error('Failed initializing Supabase cloud service', e);
    }
  }

  /// Checks if active internet connectivity is available
  Future<bool> checkInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return !connectivityResult.contains(ConnectivityResult.none);
    } catch (e) {
      AppLogger.error('Failed checking connectivity', e);
      return false;
    }
  }
}
