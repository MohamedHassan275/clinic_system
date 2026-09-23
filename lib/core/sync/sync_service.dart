import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../modules/clinic/data/repo/remote_clinic_repository.dart';
import '../common/error_handler/app_logger.dart';
import '../database/database_helper.dart';
import '../services/supabase_service.dart';

enum SyncStatus { offline, connected, syncing, error }

/// Represents real-time data migration progress details
class MigrationProgress {
  final String currentTable;
  final int processedRows;
  final int totalRows;
  final double percentage; // 0.0 to 1.0
  final bool isCompleted;
  final bool isMigrating;

  const MigrationProgress({
    required this.currentTable,
    required this.processedRows,
    required this.totalRows,
    required this.percentage,
    required this.isCompleted,
    required this.isMigrating,
  });

  factory MigrationProgress.initial() => const MigrationProgress(
        currentTable: '',
        processedRows: 0,
        totalRows: 0,
        percentage: 0.0,
        isCompleted: false,
        isMigrating: false,
      );

  MigrationProgress copyWith({
    String? currentTable,
    int? processedRows,
    int? totalRows,
    double? percentage,
    bool? isCompleted,
    bool? isMigrating,
  }) {
    return MigrationProgress(
      currentTable: currentTable ?? this.currentTable,
      processedRows: processedRows ?? this.processedRows,
      totalRows: totalRows ?? this.totalRows,
      percentage: percentage ?? this.percentage,
      isCompleted: isCompleted ?? this.isCompleted,
      isMigrating: isMigrating ?? this.isMigrating,
    );
  }
}

/// Outbox Pattern & Delta Sync Engine between local SQLite and cloud Supabase
class SyncService {
  static final SyncService instance = SyncService._init();

  SyncService._init();

  SyncStatus _status = SyncStatus.offline;
  String? _lastSyncError;
  DateTime? _lastSyncTime;
  bool _isSyncEnabled = true;

  // 1. Mutex Lock
  bool _isSyncing = false;
  Completer<void>? _currentSyncCompleter;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _periodicSyncTimer;

  SyncStatus get status => _status;
  String? get lastSyncError => _lastSyncError;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isSyncEnabled => _isSyncEnabled;
  bool get isSyncing => _isSyncing;

  final ValueNotifier<SyncStatus> statusNotifier = ValueNotifier<SyncStatus>(SyncStatus.offline);
  final ValueNotifier<MigrationProgress> migrationProgressNotifier =
      ValueNotifier<MigrationProgress>(MigrationProgress.initial());

  // 6. Sync Order: Strict 18 Tables Dependency Order
  static const List<String> _syncableTables = [
    'clinics',
    'users',
    'patients',
    'appointments',
    'waiting_queue',
    'medical_records',
    'prescriptions',
    'prescription_items',
    'invoices',
    'invoice_items',
    'refunds',
    'inventory',
    'shifts',
    'lab_results',
    'patient_attachments',
    'categories',
    'services',
    'insurance_companies',
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

  // 5. Connectivity Listener & Exponential Backoff
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
      if (_isSyncEnabled && !_isSyncing) {
        syncAll();
      }
    });
  }

  // 3. Sync Metadata Helpers (sync_metadata table)
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

  // 4. Migration Mode Helpers
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
  // Full Sync Pipeline (With Mutex Lock)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> syncAll() async {
    if (!_isSyncEnabled) {
      _setStatus(SyncStatus.offline);
      return;
    }

    // 1. Mutex Lock Check
    if (_isSyncing) {
      AppLogger.info('Sync is already in progress. Waiting for current sync completer...');
      return _currentSyncCompleter?.future ?? Future.value();
    }

    final isConnected = await SupabaseService.instance.checkInternetConnection();
    if (!isConnected) {
      _setStatus(SyncStatus.offline);
      return;
    }

    _isSyncing = true;
    _currentSyncCompleter = Completer<void>();
    _setStatus(SyncStatus.syncing);

    try {
      // 4. Check Migration Mode
      final migrationDone = await isMigrationCompleted();

      await pushPendingChanges();
      await pullRemoteChanges(isInitialMigration: !migrationDone);

      if (!migrationDone) {
        await setMigrationCompleted();
        AppLogger.info('Initial data migration completed successfully. Marked migration_completed = true.');
      }

      _lastSyncTime = DateTime.now();
      _lastSyncError = null;
      _setStatus(SyncStatus.connected);
    } catch (e) {
      _lastSyncError = e.toString();
      AppLogger.error('SyncAll failed: $e');
      _setStatus(SyncStatus.error);
    } finally {
      // 1. Mutex Lock Release
      _isSyncing = false;
      if (!(_currentSyncCompleter?.isCompleted ?? true)) {
        _currentSyncCompleter?.complete();
      }
      _currentSyncCompleter = null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. Push Operations (Local sync_queue -> Cloud RemoteClinicRepository)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> pushPendingChanges() async {
    await _pushSyncQueue();
  }

  Future<void> _pushSyncQueue() async {
    final pendingItems = await DatabaseHelper.instance.getPendingSyncQueue(limit: 50);
    if (pendingItems.isEmpty) return;

    final deviceId = await DatabaseHelper.instance.getOrCreateDeviceId();

    for (int i = 0; i < pendingItems.length; i++) {
      final item = pendingItems[i];
      final int queueId = item['id'] as int;
      final String table = item['table_name'] as String;
      final int recordId = item['record_id'] as int;
      String? remoteId = item['remote_id'] as String?;
      final String op = item['operation'] as String;
      final String? payloadStr = item['payload'] as String?;
      final int retryCount = item['retry_count'] as int? ?? 0;

      final double pct = ((i + 1) / pendingItems.length).clamp(0.0, 1.0);
      migrationProgressNotifier.value = migrationProgressNotifier.value.copyWith(
        currentTable: table,
        processedRows: i + 1,
        totalRows: pendingItems.length,
        percentage: pct,
        isMigrating: true,
        isCompleted: false,
      );

      if (retryCount >= 5) continue;

      // 5. Exponential Backoff: 2s -> 4s -> 8s -> 16s -> 32s
      if (retryCount > 0) {
        final delaySeconds = math.min(math.pow(2, retryCount).toInt(), 32);
        AppLogger.info('Retrying sync queue item #$queueId (attempt $retryCount) with ${delaySeconds}s exponential backoff...');
        await Future.delayed(Duration(seconds: delaySeconds));
      }

      try {
        Map<String, dynamic> payload = {};
        if (payloadStr != null && payloadStr.isNotEmpty) {
          payload = jsonDecode(payloadStr) as Map<String, dynamic>;
        }

        final Map<String, dynamic> remotePayload = Map<String, dynamic>.from(payload);
        remotePayload.remove('sync_status');

        final bool isDeletedLocally = (remotePayload['is_deleted'] == 1 || remotePayload['is_deleted'] == true || op == 'DELETE');
        remotePayload.remove('is_deleted');

        if (isDeletedLocally) {
          remotePayload['deleted_at'] ??= DateTime.now().toIso8601String();
        }

        // Fetch remoteId from local SQLite table if missing
        remoteId ??= await DatabaseHelper.instance.getLocalRecordRemoteId(table, recordId);

        // 2. UPDATE check: if remote_id is null, do INSERT first to assign remote_id
        String effectiveOp = op;
        if (op == 'UPDATE' && (remoteId == null || remoteId.isEmpty)) {
          AppLogger.info('UPDATE event for #$recordId in $table missing remote_id. Falling back to INSERT first.');
          effectiveOp = 'INSERT';
        }

        switch (effectiveOp) {
          case 'INSERT':
            final result = await RemoteClinicRepository.instance.insertRecord(
              table: table,
              data: remotePayload,
            );
            await result.fold(
              (failure) => throw Exception(failure.message),
              (newRemoteId) async {
                remoteId = newRemoteId;
                await DatabaseHelper.instance.updateRecordRemoteId(table, recordId, remoteId!);
              },
            );
            break;

          case 'UPDATE':
            if (remoteId != null && remoteId.isNotEmpty) {
              final result = await RemoteClinicRepository.instance.updateRecord(
                table: table,
                remoteId: remoteId,
                data: remotePayload,
              );
              result.fold(
                (failure) => throw Exception(failure.message),
                (_) {},
              );
            }
            break;

          case 'DELETE':
            if (remoteId != null && remoteId.isNotEmpty) {
              final result = await RemoteClinicRepository.instance.softDeleteRecord(
                table: table,
                remoteId: remoteId,
              );
              result.fold(
                (failure) => throw Exception(failure.message),
                (_) {},
              );
            }
            break;
        }

        await DatabaseHelper.instance.markSyncQueueItemSynced(queueId);
        await DatabaseHelper.instance.insertSyncLog(
          tableName: table,
          operation: effectiveOp,
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

    migrationProgressNotifier.value = migrationProgressNotifier.value.copyWith(
      isCompleted: true,
      isMigrating: false,
      percentage: 1.0,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. Pull Operations (Cloud RemoteClinicRepository -> Local SQLite Delta Pull)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> pullRemoteChanges({bool isInitialMigration = false}) async {
    final db = await DatabaseHelper.instance.database;
    final deviceId = await DatabaseHelper.instance.getOrCreateDeviceId();

    // 3. since = __global_last_pull_at__
    final String? globalLastPull = await getGlobalLastPullAt();

    // 6. Pull in strict 18 Tables order
    for (final table in _syncableTables) {
      try {
        final String? tableLastPull = await getTableLastPullAt(table) ?? globalLastPull;

        final result = await RemoteClinicRepository.instance.fetchRecordsSince(
          table: table,
          since: (tableLastPull != null && tableLastPull.isNotEmpty && !isInitialMigration) ? tableLastPull : null,
          limit: 500,
        );

        await result.fold(
          (failure) async {
            AppLogger.error('Failed pulling delta changes for table $table: ${failure.message}');
            await DatabaseHelper.instance.insertSyncLog(
              tableName: table,
              operation: 'PULL',
              status: 'failed',
              details: failure.message,
              deviceId: deviceId,
            );
          },
          (remoteRows) async {
            if (remoteRows.isEmpty) return;

            int pulledCount = 0;
            for (final remoteRow in remoteRows) {
              await _upsertLocal(db, table, remoteRow, isInitialMigration: isInitialMigration);
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
          },
        );
      } catch (e) {
        AppLogger.error('Error in pull pipeline for table $table: $e');
      }
    }

    // 3. Update __global_last_pull_at__
    await setGlobalLastPullAt(DateTime.now());
  }

  /// Encodes Dart bool, Map, and List types into SQLite compatible types (int, String)
  Map<String, dynamic> _sanitizeRowForSqlite(Map<String, dynamic> row) {
    final Map<String, dynamic> sanitized = {};
    row.forEach((key, value) {
      if (value is bool) {
        sanitized[key] = value ? 1 : 0;
      } else if (value is Map || value is List) {
        sanitized[key] = jsonEncode(value);
      } else {
        sanitized[key] = value;
      }
    });
    return sanitized;
  }

  /// Upserts remote row into local SQLite with Last-Write-Wins (LWW) conflict resolution by remote_id
  Future<void> _upsertLocal(Database db, String table, Map<String, dynamic> remoteRow, {bool isInitialMigration = false}) async {
    final String? remoteId = remoteRow['id'] as String?;
    if (remoteId == null || remoteId.isEmpty) return;

    final Map<String, dynamic> localRow = _sanitizeRowForSqlite(remoteRow);

    localRow['sync_status'] = 'synced';

    if (localRow.containsKey('deleted_at') && localRow['deleted_at'] != null) {
      localRow['is_deleted'] = 1;
    }

    // 4. Migration Mode: NO DELETE on local records during initial migration
    if (isInitialMigration && localRow['is_deleted'] == 1) {
      return;
    }

    // 6. LWW Conflict Resolution: Query local SQLite by remote_id (UUID)
    final localRows = await db.query(table, where: 'remote_id = ?', whereArgs: [remoteId]);
    if (localRows.isNotEmpty) {
      final existingLocal = localRows.first;
      final String? localUpdatedAtStr = existingLocal['updated_at'] as String?;
      final String? remoteUpdatedAtStr = remoteRow['updated_at'] as String?;

      if (localUpdatedAtStr != null && remoteUpdatedAtStr != null) {
        final localDate = DateTime.tryParse(localUpdatedAtStr);
        final remoteDate = DateTime.tryParse(remoteUpdatedAtStr);

        if (localDate != null && remoteDate != null && localDate.isAfter(remoteDate)) {
          AppLogger.info('Conflict Resolution (LWW): Local record with remote_id #$remoteId in table $table is newer than remote. Retaining local.');
          return;
        }
      }

      // Preserve local autoincrement ID
      localRow['id'] = existingLocal['id'];
      localRow['remote_id'] = remoteId;
      await db.update(table, localRow, where: 'id = ?', whereArgs: [existingLocal['id']]);
    } else {
      // New record from remote: remove UUID string from 'id', store in 'remote_id'
      localRow['remote_id'] = remoteId;
      localRow.remove('id'); // Allow SQLite autoincrement integer PK
      await db.insert(
        table,
        localRow,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}
