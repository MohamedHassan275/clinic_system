import 'dart:io';
import 'package:clinic_system/core/database/database_helper.dart';
import 'package:clinic_system/core/sync/sync_service.dart';
import 'package:clinic_system/core/sync/widgets/migration_progress_dialog.dart';
import 'package:clinic_system/core/sync/widgets/sync_status_indicator.dart';
import 'package:clinic_system/modules/clinic/view/screens/sync_status_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.createTempSync('db_test_').path;
        }
        return null;
      },
    );

    await DatabaseHelper.instance.database;
  });

  setUp(() {
    SyncService.instance.statusNotifier.value = SyncStatus.offline;
    SyncService.instance.migrationProgressNotifier.value = MigrationProgress.initial();
  });

  group('Phase 8 - Sync Widgets & Integration Tests', () {
    // =========================================================================
    // Group 1: SyncStatusIndicator (4 Tests)
    // =========================================================================
    group('1. SyncStatusIndicator Widget Tests', () {
      testWidgets('1. renders connected status correctly', (tester) async {
        SyncService.instance.statusNotifier.value = SyncStatus.connected;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(),
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);
        expect(find.byType(Tooltip), findsOneWidget);
      });

      testWidgets('2. renders syncing status correctly', (tester) async {
        SyncService.instance.statusNotifier.value = SyncStatus.syncing;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(),
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.cloud_sync_rounded), findsOneWidget);
      });

      testWidgets('3. renders offline status correctly', (tester) async {
        SyncService.instance.statusNotifier.value = SyncStatus.offline;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(),
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      });

      testWidgets('4. renders error status correctly', (tester) async {
        SyncService.instance.statusNotifier.value = SyncStatus.error;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(),
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.cloud_queue_rounded), findsOneWidget);
      });
    });

    // =========================================================================
    // Group 2: MigrationProgressDialog (2 Tests)
    // =========================================================================
    group('2. MigrationProgressDialog Widget Tests', () {
      testWidgets('1. renders initial migration dialog state', (tester) async {
        SyncService.instance.migrationProgressNotifier.value = MigrationProgress.initial();

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MigrationProgressDialog(),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('الهجرة الأولى للبيانات'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      });

      testWidgets('2. renders migration table progress and percentage', (tester) async {
        SyncService.instance.migrationProgressNotifier.value = const MigrationProgress(
          currentTable: 'patients',
          processedRows: 15,
          totalRows: 30,
          percentage: 0.5,
          isCompleted: false,
          isMigrating: true,
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MigrationProgressDialog(),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('الهجرة الأولى للبيانات'), findsOneWidget);
        expect(find.textContaining('patients'), findsOneWidget);
        expect(find.text('الصفوف المعالجة: 15 / 30'), findsOneWidget);
        expect(find.text('50.0%'), findsOneWidget);
      });
    });

    // =========================================================================
    // Group 3: SyncStatusScreen (2 Tests)
    // =========================================================================
    group('3. SyncStatusScreen Integration Tests', () {
      testWidgets('1. renders screen headers, KPI cards and action buttons', (tester) async {
        await tester.runAsync(() async {
          await tester.pumpWidget(
            const MaterialApp(
              home: SyncStatusScreen(),
            ),
          );
          await Future.delayed(const Duration(milliseconds: 300));
        });
        await tester.pump();

        expect(find.text('حالة المزامنة السحابية (Cloud Sync Monitor)'), findsOneWidget);
        expect(find.text('مزامنة الآن'), findsOneWidget);
        expect(find.text('إعادة المحاولة للفاشلة'), findsOneWidget);
        expect(find.text('سجلات المزامنة الأخيرة (Recent Sync Logs)'), findsOneWidget);
      });

      testWidgets('2. loads and renders recent sync log entries in data table', (tester) async {
        final db = await DatabaseHelper.instance.database;

        await db.insert('sync_log', {
          'sync_time': '2026-09-23T10:00:00.000Z',
          'table_name': 'patients',
          'operation': 'INSERT',
          'local_id': 1,
          'remote_id': 'uuid-1234',
          'status': 'success',
          'details': 'Pushed test record',
          'device_id': 'test-device',
        });

        await tester.runAsync(() async {
          await tester.pumpWidget(
            const MaterialApp(
              home: SyncStatusScreen(),
            ),
          );
          await Future.delayed(const Duration(milliseconds: 300));
        });
        await tester.pump();

        expect(find.text('patients'), findsOneWidget);
        expect(find.text('Pushed test record'), findsOneWidget);
        expect(find.text('نجاح'), findsOneWidget);
      });
    });
  });
}
