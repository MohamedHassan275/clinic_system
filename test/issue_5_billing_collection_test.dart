import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:clinic_system/core/common/error_handler/failure.dart';
import 'package:clinic_system/modules/clinic/data/cubit/clinic_cubit.dart';
import 'package:clinic_system/modules/clinic/data/repo/clinic_repo.dart';

class FakeBillingRepo extends Fake implements ClinicRepo {
  List<Map<String, dynamic>> mockInvoices = [];
  bool shouldFail = false;

  @override
  Future<Either<Failure, int>> createInvoice(Map<String, dynamic> invoice) async {
    if (shouldFail) {
      return Left(Failure(500, 'فشل إصدار الفاتورة في قاعدة البيانات'));
    }
    final newInv = Map<String, dynamic>.from(invoice);
    newInv['id'] = mockInvoices.length + 1;
    newInv['refunded_amount'] = 0.0;
    mockInvoices.insert(0, newInv);
    return Right(newInv['id'] as int);
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getInvoices() async {
    return Right(mockInvoices);
  }

  @override
  Future<Either<Failure, void>> refundInvoice({
    required int invoiceId,
    required double refundAmount,
    required String reason,
    required int userId,
    required int shiftId,
    required int patientId,
  }) async {
    final index = mockInvoices.indexWhere((i) => i['id'] == invoiceId);
    if (index != -1) {
      final currentRefund = (mockInvoices[index]['refunded_amount'] as num?)?.toDouble() ?? 0.0;
      mockInvoices[index]['refunded_amount'] = currentRefund + refundAmount;
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getDashboardStats({int clinicId = 1}) async {
    return Right({
      'todayAppointments': 1,
      'waitingCount': 0,
      'totalPatients': 1,
      'todayRevenue': mockInvoices.fold(0.0, (sum, i) => sum + ((i['paid_amount'] as num?)?.toDouble() ?? 0.0)),
    });
  }
}

void main() {
  group('Issue 5: Billing Invoice Collection Unit Tests', () {
    test('1. createInvoice injects fallback fields and auto-refreshes invoices list', () async {
      final fakeRepo = FakeBillingRepo();
      final cubit = ClinicCubit(fakeRepo);

      expect(cubit.invoices.isEmpty, isTrue);

      final result = await cubit.createInvoice({
        'patient_id': 1,
        'paid_amount': 300.0,
        'payment_method': 'cash',
      });

      expect(result.isRight(), isTrue);
      result.fold((_) {}, (id) => expect(id, equals(1)));

      expect(cubit.invoices.length, equals(1));
      final inv = cubit.invoices.first;
      expect(inv['patient_id'], equals(1));
      expect(inv['paid_amount'], equals(300.0));
      expect(inv['user_id'], equals(1));
      expect(inv['shift_id'], equals(1));
      expect(inv['clinic_id'], equals(1));
      expect(inv['payment_method'], equals('cash'));

      await cubit.close();
    });

    test('2. createInvoice supports split payment mode with cash and card portions', () async {
      final fakeRepo = FakeBillingRepo();
      final cubit = ClinicCubit(fakeRepo);

      final result = await cubit.createInvoice({
        'patient_id': 2,
        'paid_amount': 500.0,
        'cash_amount': 200.0,
        'card_amount': 300.0,
        'payment_method': 'split',
      });

      expect(result.isRight(), isTrue);
      expect(cubit.invoices.first['payment_method'], equals('split'));
      expect(cubit.invoices.first['cash_amount'], equals(200.0));
      expect(cubit.invoices.first['card_amount'], equals(300.0));

      await cubit.close();
    });

    test('3. createInvoice returns Left(Failure) when database insertion fails', () async {
      final fakeRepo = FakeBillingRepo()..shouldFail = true;
      final cubit = ClinicCubit(fakeRepo);

      final result = await cubit.createInvoice({
        'patient_id': 1,
        'paid_amount': 300.0,
      });

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, contains('فشل إصدار الفاتورة')),
        (_) => fail('Should have failed'),
      );

      await cubit.close();
    });

    test('4. refundInvoice updates refunded amount and refreshes invoices state', () async {
      final fakeRepo = FakeBillingRepo();
      final cubit = ClinicCubit(fakeRepo);

      await cubit.createInvoice({
        'patient_id': 1,
        'paid_amount': 400.0,
        'payment_method': 'cash',
      });

      final invId = cubit.invoices.first['id'] as int;
      final refundRes = await cubit.refundInvoice(
        invoiceId: invId,
        refundAmount: 150.0,
        reason: 'طلب إرجاع جزئي',
        patientId: 1,
      );

      expect(refundRes.isRight(), isTrue);
      expect(cubit.invoices.first['refunded_amount'], equals(150.0));

      await cubit.close();
    });
  });
}
