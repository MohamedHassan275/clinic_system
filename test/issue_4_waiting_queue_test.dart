import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:clinic_system/core/common/error_handler/failure.dart';
import 'package:clinic_system/core/enums/appointment_enums.dart';
import 'package:clinic_system/modules/clinic/data/cubit/clinic_cubit.dart';
import 'package:clinic_system/modules/clinic/data/repo/clinic_repo.dart';

class FakeWaitingQueueRepo extends Fake implements ClinicRepo {
  List<Map<String, dynamic>> mockAppointments = [
    {
      'id': 101,
      'patient_id': 1,
      'patient_name': 'مريض عادي',
      'clinic_id': 1,
      'appointment_date': '2026-09-14',
      'status': 'waiting',
      'priority': 'normal',
    },
    {
      'id': 102,
      'patient_id': 2,
      'patient_name': 'مريض طوارئ',
      'clinic_id': 1,
      'appointment_date': '2026-09-14',
      'status': 'waiting',
      'priority': 'emergency',
    },
    {
      'id': 103,
      'patient_id': 3,
      'patient_name': 'مريض جاري الكشف',
      'clinic_id': 1,
      'appointment_date': '2026-09-14',
      'status': 'in_progress',
      'priority': 'urgent',
    },
    {
      'id': 104,
      'patient_id': 4,
      'patient_name': 'مريض مكتمل',
      'clinic_id': 1,
      'appointment_date': '2026-09-14',
      'status': 'completed',
      'priority': 'normal',
    },
  ];

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getWaitingRoomQueue({int clinicId = 1, String? date}) async {
    final filtered = mockAppointments.where((a) {
      final matchesClinic = a['clinic_id'] == clinicId;
      final status = (a['status'] as String).toLowerCase();
      final isWaitingOrInProgress = status == 'waiting' || status == 'in_progress';
      return matchesClinic && isWaitingOrInProgress;
    }).toList();

    filtered.sort((a, b) {
      int pRank(String p) {
        switch (p.toLowerCase()) {
          case 'emergency':
          case 'stat':
            return 1;
          case 'urgent':
            return 2;
          default:
            return 3;
        }
      }

      final rA = pRank(a['priority'] as String);
      final rB = pRank(b['priority'] as String);
      if (rA != rB) return rA.compareTo(rB);
      return (a['id'] as int).compareTo(b['id'] as int);
    });

    return Right(filtered);
  }

  @override
  Future<Either<Failure, void>> updateAppointmentStatus(int id, String status) async {
    final index = mockAppointments.indexWhere((a) => a['id'] == id);
    if (index != -1) {
      mockAppointments[index]['status'] = AppointmentStatus.fromString(status).dbValue;
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getAppointments({int? clinicId, String? date, String? status}) async {
    return Right(mockAppointments);
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getDashboardStats({int clinicId = 1}) async {
    return Right({
      'todayAppointments': mockAppointments.length,
      'waitingCount': mockAppointments.where((a) => a['status'] == 'waiting').length,
      'totalPatients': 4,
      'todayRevenue': 0.0,
    });
  }
}

void main() {
  group('Issue 4: Waiting Queue & Priority Ordering Unit Tests', () {
    test('1. fetchWaitingQueue filters only waiting/in_progress patients and orders by priority', () async {
      final fakeRepo = FakeWaitingQueueRepo();
      final cubit = ClinicCubit(fakeRepo);

      final result = await cubit.fetchWaitingQueue(clinicId: 1);
      expect(result.isRight(), isTrue);

      final queue = cubit.waitingQueue;
      expect(queue.length, equals(3)); // Excludes completed patient (104)

      // First should be emergency patient (102)
      expect(queue[0]['id'], equals(102));
      expect(queue[0]['patient_name'], equals('مريض طوارئ'));

      // Second should be urgent patient (103)
      expect(queue[1]['id'], equals(103));

      // Third should be normal patient (101)
      expect(queue[2]['id'], equals(101));

      await cubit.close();
    });

    test('2. checkInPatient updates appointment status to in_progress in English and refreshes queue', () async {
      final fakeRepo = FakeWaitingQueueRepo();
      final cubit = ClinicCubit(fakeRepo);

      await cubit.fetchWaitingQueue(clinicId: 1);
      expect(cubit.waitingQueue.firstWhere((a) => a['id'] == 101)['status'], equals('waiting'));

      // Check-in normal patient (101)
      final checkInRes = await cubit.checkInPatient(101);
      expect(checkInRes.isRight(), isTrue);

      // Verify status changed to 'in_progress' and patient remains in waiting room queue
      final updatedAppt = fakeRepo.mockAppointments.firstWhere((a) => a['id'] == 101);
      expect(updatedAppt['status'], equals('in_progress'));

      expect(cubit.waitingQueue.any((a) => a['id'] == 101), isTrue);

      await cubit.close();
    });
  });
}
