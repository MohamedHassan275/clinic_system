import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/common/error_handler/failure.dart';

/// مستودع البيانات السحابي لخدمة SyncService وتيسير عمليات الـ Outbox Pattern & Delta Sync
class RemoteClinicRepository {
  static final RemoteClinicRepository instance = RemoteClinicRepository._init();

  RemoteClinicRepository._init();

  SupabaseClient get _client => Supabase.instance.client;

  /// 1. إنشاء سجل جديد في السحابة وإرجاع الـ UUID (remote_id) الناتجة
  Future<Either<Failure, String>> insertRecord({
    required String table,
    required Map<String, dynamic> data,
  }) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      payload.remove('id'); // Local SQLite auto-increment PK
      payload.remove('sync_status');
      payload.remove('is_deleted');

      final res = await _client.from(table).insert(payload).select('id').single();
      final String remoteId = res['id'] as String;
      return Right(remoteId);
    } catch (e) {
      return Left(Failure(500, "فشل إنشاء السجل في الجدول $table سحابياً: $e"));
    }
  }

  /// 2. تحديث سجل قائم في السحابة باستعمال الـ remoteId (UUID)
  Future<Either<Failure, void>> updateRecord({
    required String table,
    required String remoteId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      payload.remove('id');
      payload.remove('sync_status');
      payload.remove('is_deleted');
      payload['updated_at'] = DateTime.now().toIso8601String();

      await _client.from(table).update(payload).eq('id', remoteId);
      return const Right(null);
    } catch (e) {
      return Left(Failure(500, "فشل تحديث السجل #$remoteId في الجدول $table سحابياً: $e"));
    }
  }

  /// 3. حذف منطقي لسجل سحابي باستعمال الـ remoteId (UUID)
  Future<Either<Failure, void>> softDeleteRecord({
    required String table,
    required String remoteId,
  }) async {
    try {
      await _client.from(table).update({
        'deleted_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', remoteId);
      return const Right(null);
    } catch (e) {
      return Left(Failure(500, "فشل حذف السجل #$remoteId من الجدول $table سحابياً: $e"));
    }
  }

  /// 4. جلب التحديثات السحابية الجديدة (Delta Pull) منذ تاريخ محدد (تشمل المحذوفة للمزامنة)
  Future<Either<Failure, List<Map<String, dynamic>>>> fetchRecordsSince({
    required String table,
    String? since,
    int limit = 500,
  }) async {
    try {
      var builder = _client.from(table).select();

      if (since != null && since.trim().isNotEmpty) {
        builder = builder.gt('updated_at', since.trim());
      }

      final res = await builder.order('updated_at', ascending: true).limit(limit);
      final list = List<Map<String, dynamic>>.from(res as List);
      return Right(list);
    } catch (e) {
      return Left(Failure(500, "فشل جلب التحديثات السحابية للجدول $table: $e"));
    }
  }

  /// 5. جلب سجل واحد بمُعرِّف الـ remoteId (UUID)
  Future<Either<Failure, Map<String, dynamic>?>> fetchRecordById({
    required String table,
    required String remoteId,
  }) async {
    try {
      final res = await _client
          .from(table)
          .select()
          .eq('id', remoteId)
          .filter('deleted_at', 'is', null)
          .maybeSingle();
      return Right(res);
    } catch (e) {
      return Left(Failure(500, "فشل جلب السجل #$remoteId من الجدول $table سحابياً: $e"));
    }
  }
}
