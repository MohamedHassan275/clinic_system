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
    if (!enabled) {
      _setStatus(SyncStatus.offline);
      return;
    }
    syncAll();
  }

  void _setStatus(SyncStatus newStatus) {
    _status = newStatus;
    statusNotifier.value = newStatus;
  }

  void _startConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = !results.contains(ConnectivityResult.none);
      if (!isConnected) {
        _setStatus(SyncStatus.offline);
        return;
      }
      if (_isSyncEnabled) {
        syncAll();
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

  // ═══════════════════════════════════════════════════════════════════════════
  // Sync Metadata Helpers (sync_metadata table)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<String?> getGlobalLastPullAt() async {
    final meta = await DatabaseHelper.instance.getSyncMetadata('__global__');
    return meta?['last_pull_at'] as String?;
  }

  Future<void> setGlobalLastPullAt(DateTime dt) async {
    await DatabaseHelper.instance.setSyncMetadata(
      '__global__',
      lastPullAt: dt.toIso8601String(),
    );
  }

  Future<String?> getTableLastPullAt(String table) async {
    final meta = await DatabaseHelper.instance.getSyncMetadata(table);
    return meta?['last_pull_at'] as String?;
  }

  Future<void> setTableLastPullAt(String table, DateTime dt) async {
    await DatabaseHelper.instance.setSyncMetadata(
      table,
      lastPullAt: dt.toIso8601String(),
    );
  }

  Future<bool> isMigrationCompleted() async {
    final meta = await DatabaseHelper.instance.getSyncMetadata('migration');
    return meta?['last_sync_at'] != null;
  }

  Future<void> setMigrationCompleted() async {
    await DatabaseHelper.instance.setSyncMetadata(
      'migration',
      lastSyncAt: DateTime.now().toIso8601String(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Full Sync Pipeline
  // ═══════════════════════════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════════════════════════
  // Push Operations (Local sync_queue & sync_outbox -> Cloud Supabase)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> pushPendingChanges() async {
    final client = _supabaseClient;
    if (client == null) return;

    await _pushSyncQueue(client);
    await _pushSyncOutbox(client);
  }

  Future<void> _pushSyncQueue(SupabaseClient client) async {
    final pendingItems = await DatabaseHelper.instance.getPendingSyncQueue(limit: 50);
    if (pendingItems.isEmpty) return;

    final deviceId = await DatabaseHelper.instance.getOrCreateDeviceId();

    for (final item in pendingItems) {
      final int queueId = item['id'] as int;
      final String table = item['table_name'] as String;
      final int recordId = item['record_id'] as int;
      final String? remoteId = item['remote_id'] as String?;
      final String op = item['operation'] as String;
      final String? payloadStr = item['payload'] as String?;
      final int retryCount = item['retry_count'] as int? ?? 0;

      if (retryCount >= 5) continue;

      if (retryCount > 0) {
        final delaySeconds = math.min(math.pow(2, retryCount).toInt(), 30);
        AppLogger.info('Retrying sync queue item #$queueId (attempt $retryCount) with ${delaySeconds}s exponential backoff...');
        await Future.delayed(Duration(seconds: delaySeconds));
      }

      try {
        Map<String, dynamic> payload = {};
        if (payloadStr != null && payloadStr.isNotEmpty) {
          payload = jsonDecode(payloadStr) as Map<String, dynamic>;
        }

        // Clean payload for Supabase: remove local-only columns sync_status and is_deleted
        final Map<String, dynamic> remotePayload = Map<String, dynamic>.from(payload);
        remotePayload.remove('sync_status');

        final bool isDeletedLocally = (remotePayload['is_deleted'] == 1 || remotePayload['is_deleted'] == true || op == 'DELETE');
        remotePayload.remove('is_deleted');

        if (isDeletedLocally) {
          remotePayload['deleted_at'] ??= DateTime.now().toIso8601String();
        }

        switch (op) {
          case 'INSERT':
          case 'UPDATE':
            await client.from(table).upsert(remotePayload);
            break;
          case 'DELETE':
            await client.from(table).update({
              'deleted_at': DateTime.now().toIso8601String(),
            }).eq('id', recordId);
            break;
        }

        await DatabaseHelper.instance.markSyncQueueItemSynced(queueId);
        await DatabaseHelper.instance.insertSyncLog(
          tableName: table,
          operation: op,
          localId: recordId,
          remoteId: remoteId,
          status: 'success',
          details: 'Pushed item #$queueId via sync_queue',
          deviceId: deviceId,
        );
      } catch (e) {
        AppLogger.error('Failed pushing sync_queue item #$queueId for table $table: $e');
        await DatabaseHelper.instance.markSyncQueueItemFailed(queueId, e.toString(), retryCount + 1);
        await DatabaseHelper.instance.insertSyncLog(
          tableName: table,
          operation: op,
          localId: recordId,
          remoteId: remoteId,
          status: 'failed',
          details: e.toString(),
          deviceId: deviceId,
        );
      }
    }
  }

  Future<void> _pushSyncOutbox(SupabaseClient client) async {
    final pendingEvents = await DatabaseHelper.instance.getPendingOutboxEvents(limit: 50);
    if (pendingEvents.isEmpty) return;

    final deviceId = await DatabaseHelper.instance.getOrCreateDeviceId();

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

        // Clean payload for Supabase: remove local-only columns sync_status and is_deleted
        final Map<String, dynamic> remotePayload = Map<String, dynamic>.from(payload);
        remotePayload.remove('sync_status');

        final bool isDeletedLocally = (remotePayload['is_deleted'] == 1 || remotePayload['is_deleted'] == true || op == 'DELETE');
        remotePayload.remove('is_deleted');

        if (isDeletedLocally) {
          remotePayload['deleted_at'] ??= DateTime.now().toIso8601String();
        }

        switch (op) {
          case 'INSERT':
            await client.from(table).upsert(remotePayload);
            break;
          case 'UPDATE':
            await client.from(table).update(remotePayload).eq('id', recordId);
            break;
          case 'DELETE':
            await client.from(table).update({
              'deleted_at': DateTime.now().toIso8601String(),
            }).eq('id', recordId);
            break;
        }

        await DatabaseHelper.instance.markOutboxEventSynced(outboxId);
        await DatabaseHelper.instance.insertSyncLog(
          tableName: table,
          operation: op,
          localId: recordId,
          status: 'success',
          details: 'Pushed outbox event #$outboxId',
          deviceId: deviceId,
        );
      } catch (e) {
        AppLogger.error('Failed pushing outbox event #$outboxId for table $table: $e');
        await DatabaseHelper.instance.markOutboxEventFailed(outboxId, e.toString());
        await DatabaseHelper.instance.insertSyncLog(
          tableName: table,
          operation: op,
          localId: recordId,
          status: 'failed',
          details: e.toString(),
          deviceId: deviceId,
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Pull Operations (Cloud Supabase -> Local SQLite Delta Pull)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> pullRemoteChanges() async {
    final client = _supabaseClient;
    if (client == null) return;

    final db = await DatabaseHelper.instance.database;
    final deviceId = await DatabaseHelper.instance.getOrCreateDeviceId();

    final user = SessionManager.instance.currentUser;
    final int clinicId = (user != null && user['clinic_id'] != null) ? (user['clinic_id'] as int) : 1;

    final String? globalLastPull = await getGlobalLastPullAt();

    for (final table in _syncableTables) {
      try {
        final String? tableLastPull = await getTableLastPullAt(table) ?? globalLastPull;

        dynamic query = client.from(table).select();

        if (table != 'settings' && table != 'icd10_codes') {
          query = query.eq('clinic_id', clinicId);
        }

        if (tableLastPull != null && tableLastPull.isNotEmpty) {
          query = query.gt('updated_at', tableLastPull);
        } else {
          query = query.limit(500);
        }

        final List<dynamic> remoteRows = await query;
        if (remoteRows.isEmpty) continue;

        int pulledCount = 0;
        for (final item in remoteRows) {
          if (item is! Map<String, dynamic>) continue;
          final Map<String, dynamic> remoteRow = Map<String, dynamic>.from(item);

          await _upsertLocal(db, table, remoteRow);
          pulledCount++;
        }

        final pullTime = DateTime.now();
        await setTableLastPullAt(table, pullTime);

        await DatabaseHelper.instance.insertSyncLog(
          tableName: table,
          operation: 'PULL',
          status: 'success',
          details: 'Pulled $pulledCount remote rows',
          deviceId: deviceId,
        );
      } catch (e) {
        AppLogger.error('Failed pulling delta changes for table $table: $e');
        await DatabaseHelper.instance.insertSyncLog(
          tableName: table,
          operation: 'PULL',
          status: 'failed',
          details: e.toString(),
          deviceId: deviceId,
        );
      }
    }

    await setGlobalLastPullAt(DateTime.now());
  }

  /// Upserts remote row into local SQLite with Last-Write-Wins (LWW) conflict resolution
  Future<void> _upsertLocal(Database db, String table, Map<String, dynamic> remoteRow) async {
    final Map<String, dynamic> localRow = Map<String, dynamic>.from(remoteRow);

    // Map sync_status and is_deleted for local SQLite storage
    localRow['sync_status'] = 'synced';

    if (localRow.containsKey('deleted_at') && localRow['deleted_at'] != null) {
      localRow['is_deleted'] = 1;
    }

    final int? id = localRow['id'] as int?;
    if (id == null) {
      await db.insert(table, localRow, conflictAlgorithm: ConflictAlgorithm.replace);
      return;
    }

    final localRows = await db.query(table, where: 'id = ?', whereArgs: [id]);
    if (localRows.isNotEmpty) {
      final existingLocal = localRows.first;
      final String? localUpdatedAtStr = existingLocal['updated_at'] as String?;
      final String? remoteUpdatedAtStr = remoteRow['updated_at'] as String?;

      if (localUpdatedAtStr != null && remoteUpdatedAtStr != null) {
        final localDate = DateTime.tryParse(localUpdatedAtStr);
        final remoteDate = DateTime.tryParse(remoteUpdatedAtStr);

        if (localDate != null && remoteDate != null && localDate.isAfter(remoteDate)) {
          AppLogger.info('Conflict Resolution (LWW): Local record #$id in table $table is newer than remote. Retaining local.');
          return;
        }
      }
    }

    await db.insert(
      table,
      localRow,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

