import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../common/error_handler/app_logger.dart';
import '../database/database_helper.dart';
import '../security/session_manager.dart';
import '../services/supabase_service.dart';

enum SyncStatus { offline, connected, syncing, error }

/// Outbox Pattern & Delta Sync Engine between local SQLite and cloud Supabase
class SyncService {
  static final SyncService instance = SyncService._init();

  SyncService._init();

  SyncStatus _status = SyncStatus.offline;
  String? _lastSyncError;
  DateTime? _lastSyncTime;
  bool _isSyncEnabled = true;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _periodicSyncTimer;

  SyncStatus get status => _status;
  String? get lastSyncError => _lastSyncError;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isSyncEnabled => _isSyncEnabled;

  final ValueNotifier<SyncStatus> statusNotifier = ValueNotifier<SyncStatus>(SyncStatus.offline);

  static const List<String> _syncableTables = [
    'clinics',
    'users',
    'shifts',
    'patients',
    'appointments',
    'prescriptions',
    'prescription_items',
    'invoices',
    'refunds',
    'inventory',
    'patient_attachments',
    'medicines',
    'services',
    'categories',
    'insurance_companies',
    'patient_insurance',
    'stock_movements',
    'lab_results',
    'lab_orders',
    'vitals',
    'drug_interactions',
    'prescription_templates',
    'template_items',
    'icd10_codes',
    'settings',
    'audit_log',
  ];

  /// Initializes background listeners and periodic sync timer
  void init() {
    _startConnectivityListener();
    _startPeriodicTimer();
    syncAll();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
  }

  void setSyncEnabled(bool enabled) {
    if (_isSyncEnabled == enabled) return;
    _isSyncEnabled = enabled;
    if (enabled) {
      syncAll();
      return;
    }
    _setStatus(SyncStatus.offline);
  }

  void _setStatus(SyncStatus newStatus) {
    _status = newStatus;
    statusNotifier.value = newStatus;
  }

  void _startConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = !results.contains(ConnectivityResult.none);
      if (isConnected && _isSyncEnabled) {
        syncAll();
        return;
      }
      if (!isConnected) {
        _setStatus(SyncStatus.offline);
      }
    });
  }

  void _startPeriodicTimer() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isSyncEnabled && _status != SyncStatus.syncing) {
        syncAll();
      }
    });
  }

  SupabaseClient? get _supabaseClient {
    if (!SupabaseService.instance.isInitialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Full Sync pipeline: Push local outbox changes -> Pull remote delta changes
  Future<void> syncAll() async {
    if (!_isSyncEnabled) {
      _setStatus(SyncStatus.offline);
      return;
    }

    final isConnected = await SupabaseService.instance.checkInternetConnection();
    if (!isConnected) {
      _setStatus(SyncStatus.offline);
      return;
    }

    final client = _supabaseClient;
    if (client == null) {
      _setStatus(SyncStatus.offline);
      return;
    }

    _setStatus(SyncStatus.syncing);

    try {
      await pushPendingChanges();
      await pullRemoteChanges();
      _lastSyncTime = DateTime.now();
      _lastSyncError = null;
      _setStatus(SyncStatus.connected);
    } catch (e) {
      _lastSyncError = e.toString();
      AppLogger.error('SyncAll failed: $e');
      _setStatus(SyncStatus.error);
    }
  }

  /// Push local outbox mutations to Supabase
  Future<void> pushPendingChanges() async {
    final client = _supabaseClient;
    if (client == null) return;

    final pendingEvents = await DatabaseHelper.instance.getPendingOutboxEvents(limit: 50);
    if (pendingEvents.isEmpty) return;

    for (final event in pendingEvents) {
      final int outboxId = event['id'] as int;
      final String table = event['table_name'] as String;
      final int recordId = event['record_id'] as int;
      final String op = event['operation'] as String;
      final String? payloadStr = event['payload'] as String?;
      final int retryCount = event['retry_count'] as int? ?? 0;

      if (retryCount >= 10) continue;

      if (retryCount > 0) {
        final delaySeconds = math.min(math.pow(2, retryCount).toInt(), 30);
        AppLogger.info('Retrying outbox event #$outboxId (attempt $retryCount) with ${delaySeconds}s exponential backoff...');
        await Future.delayed(Duration(seconds: delaySeconds));
      }

      try {
        Map<String, dynamic> payload = {};
        if (payloadStr != null && payloadStr.isNotEmpty) {
          payload = jsonDecode(payloadStr) as Map<String, dynamic>;
        }

        switch (op) {
          case 'INSERT':
            await client.from(table).upsert(payload);
            break;
          case 'UPDATE':
            await client.from(table).update(payload).eq('id', recordId);
            break;
          case 'DELETE':
            await client.from(table).update({
              'is_deleted': 1,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', recordId);
            break;
        }

        await DatabaseHelper.instance.markOutboxEventSynced(outboxId);
      } catch (e) {
        AppLogger.error('Failed pushing outbox event #$outboxId for table $table: $e');
        await DatabaseHelper.instance.markOutboxEventFailed(outboxId, e.toString());
      }
    }
  }

  /// Pull remote delta updates from Supabase into local SQLite with Last-Write-Wins Conflict Resolution
  Future<void> pullRemoteChanges() async {
    final client = _supabaseClient;
    if (client == null) return;

    final db = await DatabaseHelper.instance.database;

    // Get active clinic ID
    final user = SessionManager.instance.currentUser;
    final int clinicId = (user != null && user['clinic_id'] != null) ? (user['clinic_id'] as int) : 1;

    // Get last pull timestamp from local settings
    final lastPullRes = await db.query('settings', where: 'key = ?', whereArgs: ['last_pull_at']);
    final String? lastPullAt = lastPullRes.isNotEmpty ? (lastPullRes.first['value'] as String?) : null;

    final nowStr = DateTime.now().toIso8601String();

    for (final table in _syncableTables) {
      try {
        dynamic query = client.from(table).select();

        if (table != 'settings' && table != 'icd10_codes') {
          query = query.eq('clinic_id', clinicId);
        }

        if (lastPullAt != null && lastPullAt.isNotEmpty) {
          query = query.gt('updated_at', lastPullAt);
        } else {
          query = query.limit(500);
        }

        final List<dynamic> remoteRows = await query;
        if (remoteRows.isEmpty) continue;

        for (final item in remoteRows) {
          if (item is! Map<String, dynamic>) continue;
          final Map<String, dynamic> remoteRow = Map<String, dynamic>.from(item);

          await _upsertLocal(db, table, remoteRow);
        }
      } catch (e) {
        AppLogger.error('Failed pulling delta changes for table $table: $e');
      }
    }

    // Save updated last_pull_at timestamp
    await db.insert(
      'settings',
      {
        'clinic_id': clinicId,
        'key': 'last_pull_at',
        'value': nowStr,
        'updated_at': nowStr,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Upserts remote row into local SQLite with Last-Write-Wins (LWW) conflict resolution
  Future<void> _upsertLocal(Database db, String table, Map<String, dynamic> remoteRow) async {
    final int? id = remoteRow['id'] as int?;
    if (id == null) {
      await db.insert(table, remoteRow, conflictAlgorithm: ConflictAlgorithm.replace);
      return;
    }

    final localRows = await db.query(table, where: 'id = ?', whereArgs: [id]);
    if (localRows.isNotEmpty) {
      final localRow = localRows.first;
      final String? localUpdatedAtStr = localRow['updated_at'] as String?;
      final String? remoteUpdatedAtStr = remoteRow['updated_at'] as String?;

      if (localUpdatedAtStr != null && remoteUpdatedAtStr != null) {
        final localDate = DateTime.tryParse(localUpdatedAtStr);
        final remoteDate = DateTime.tryParse(remoteUpdatedAtStr);

        // If local record is strictly newer than remote record, keep local record (Local Write Wins until Outbox pushes)
        if (localDate != null && remoteDate != null && localDate.isAfter(remoteDate)) {
          AppLogger.info('Conflict Resolution (LWW): Local record #$id in table $table is newer than remote. Retaining local.');
          return;
        }
      }
    }

    // Remote is newer or record doesn't exist locally -> Upsert to local SQLite without generating new outbox records
    await db.insert(
      table,
      remoteRow,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
