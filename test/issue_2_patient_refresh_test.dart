import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:clinic_system/core/common/error_handler/failure.dart';
import 'package:clinic_system/modules/clinic/data/cubit/clinic_cubit.dart';
import 'package:clinic_system/modules/clinic/data/repo/clinic_repository.dart';

class FakeClinicRepo extends Fake implements ClinicRepository {
  List<Map<String, dynamic>> mockPatients = [];

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getPatients({String? query}) async {
    return Right(mockPatients);
  }

  @override
  Future<Either<Failure, int>> addPatient(Map<String, dynamic> patient) async {
    final newPatient = Map<String, dynamic>.from(patient);
    newPatient['id'] = mockPatients.length + 1;
    mockPatients.insert(0, newPatient);
    return Right(newPatient['id'] as int);
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getDashboardStats({int clinicId = 1}) async {
    return const Right({'todayAppointments': 0, 'waitingCount': 0, 'totalPatients': 1, 'todayRevenue': 0.0});
  }
}

void main() {
  group('Issue 2: New Patient List Auto-Refresh Unit Tests', () {
    test('1. Adding a patient via addPatient automatically fetches patients and updates cubit state list', () async {
      final fakeRepo = FakeClinicRepo();
      final cubit = ClinicCubit(fakeRepo);

      expect(cubit.patients.isEmpty, isTrue);

      final result = await cubit.addPatient({
        'name': 'محمد أحمد',
        'phone': '01012345678',
        'contract_entity': 'نقدي (خاص)',
      });

      expect(result.isRight(), isTrue);
      result.fold((_) {}, (id) => expect(id, equals(1)));

      // Verify patients list is automatically refreshed inside cubit
      expect(cubit.patients.length, equals(1));
      expect(cubit.patients.first['name'], equals('محمد أحمد'));

      await cubit.close();
    });
  });
}
