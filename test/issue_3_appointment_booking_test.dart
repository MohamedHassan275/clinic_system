import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:clinic_system/core/common/error_handler/failure.dart';
import 'package:clinic_system/modules/clinic/data/cubit/clinic_cubit.dart';
import 'package:clinic_system/modules/clinic/data/repo/clinic_repo.dart';

class FakeAppointmentRepo extends Fake implements ClinicRepo {
  List<Map<String, dynamic>> mockAppointments = [];
  List<Map<String, dynamic>> mockQueue = [];
  bool shouldFail = false;

  @override
  Future<Either<Failure, int>> addAppointment(Map<String, dynamic> appt) async {
    if (shouldFail) {
      return Left(Failure(500, 'فشل حجز الموعد في قاعدة البيانات'));
    }
    final newAppt = Map<String, dynamic>.from(appt);
    newAppt['id'] = mockAppointments.length + 1;
    mockAppointments.insert(0, newAppt);
    mockQueue.insert(0, newAppt);
    return Right(newAppt['id'] as int);
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getAppointments({int? clinicId, String? date, String? status}) async {
    return Right(mockAppointments);
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getWaitingRoomQueue({int clinicId = 1, String? date}) async {
    return Right(mockQueue);
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getDashboardStats({int clinicId = 1}) async {
    return Right({
      'todayAppointments': mockAppointments.length,
      'waitingCount': mockQueue.length,
      'totalPatients': 1,
      'todayRevenue': 0.0,
    });
  }
}

void main() {
  group('Issue 3: Appointment Booking Unit Tests', () {
    test('1. bookAppointment injects fallback values and auto-refreshes appointments and waiting queue', () async {
      final fakeRepo = FakeAppointmentRepo();
      final cubit = ClinicCubit(fakeRepo);

      expect(cubit.appointments.isEmpty, isTrue);
      expect(cubit.waitingQueue.isEmpty, isTrue);

      final result = await cubit.bookAppointment({
        'patient_id': 10,
        'type': 'newConsultation',
      });

      expect(result.isRight(), isTrue);
      result.fold((_) {}, (id) => expect(id, equals(1)));

      expect(cubit.appointments.length, equals(1));
      expect(cubit.waitingQueue.length, equals(1));

      final savedAppt = cubit.appointments.first;
      expect(savedAppt['patient_id'], equals(10));
      expect(savedAppt['user_id'], equals(1));
      expect(savedAppt['shift_id'], equals(1));
      expect(savedAppt['clinic_id'], equals(1));
      expect(savedAppt['status'], equals('waiting'));

      await cubit.close();
    });

    test('2. bookAppointment returns Left(Failure) when booking fails', () async {
      final fakeRepo = FakeAppointmentRepo()..shouldFail = true;
      final cubit = ClinicCubit(fakeRepo);

      final result = await cubit.bookAppointment({
        'patient_id': 10,
      });

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, contains('فشل حجز الموعد')),
        (_) => fail('Should have failed'),
      );

      expect(cubit.appointments.isEmpty, isTrue);

      await cubit.close();
    });
  });
}
