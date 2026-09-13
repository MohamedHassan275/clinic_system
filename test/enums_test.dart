import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_system/core/enums/user_role.dart';
import 'package:clinic_system/core/enums/appointment_enums.dart';
import 'package:clinic_system/core/enums/payment_enums.dart';
import 'package:clinic_system/core/enums/lab_enums.dart';

void main() {
  group('Core Enums Unit Tests - Comprehensive Mapping & Localization', () {
    test('1. UserRole enum maps English DB values and Arabic display names', () {
      expect(UserRole.fromString('super_admin'), equals(UserRole.superAdmin));
      expect(UserRole.superAdmin.dbValue, equals('super_admin'));
      expect(UserRole.superAdmin.displayName, contains('Super Admin'));

      expect(UserRole.fromString('doctor'), equals(UserRole.doctor));
      expect(UserRole.doctor.dbValue, equals('doctor'));

      expect(UserRole.fromString('secretary'), equals(UserRole.secretary));
      expect(UserRole.fromString('receptionist'), equals(UserRole.secretary));
      expect(UserRole.secretary.dbValue, equals('secretary'));
    });

    test('2. AppointmentStatus enum maps English DB values and Arabic display names', () {
      expect(AppointmentStatus.fromString('waiting'), equals(AppointmentStatus.waiting));
      expect(AppointmentStatus.waiting.dbValue, equals('waiting'));
      expect(AppointmentStatus.waiting.displayName, equals('في الانتظار'));

      expect(AppointmentStatus.fromString('in_progress'), equals(AppointmentStatus.inProgress));
      expect(AppointmentStatus.fromString('جاري الكشف'), equals(AppointmentStatus.inProgress));
      expect(AppointmentStatus.inProgress.dbValue, equals('in_progress'));

      expect(AppointmentStatus.fromString('completed'), equals(AppointmentStatus.completed));
      expect(AppointmentStatus.completed.dbValue, equals('completed'));
    });

    test('3. AppointmentType enum maps English DB values and Arabic display names', () {
      expect(AppointmentType.fromString('new_consultation'), equals(AppointmentType.newConsultation));
      expect(AppointmentType.newConsultation.dbValue, equals('new_consultation'));

      expect(AppointmentType.fromString('follow_up'), equals(AppointmentType.followUp));
      expect(AppointmentType.followUp.dbValue, equals('follow_up'));

      expect(AppointmentType.fromString('lab_review'), equals(AppointmentType.labReview));
      expect(AppointmentType.labReview.dbValue, equals('lab_review'));
    });

    test('4. AppointmentPriority enum maps English DB values and Arabic display names', () {
      expect(AppointmentPriority.fromString('normal'), equals(AppointmentPriority.normal));
      expect(AppointmentPriority.normal.dbValue, equals('normal'));

      expect(AppointmentPriority.fromString('urgent'), equals(AppointmentPriority.urgent));
      expect(AppointmentPriority.urgent.dbValue, equals('urgent'));

      expect(AppointmentPriority.fromString('emergency'), equals(AppointmentPriority.emergency));
      expect(AppointmentPriority.emergency.dbValue, equals('emergency'));
    });

    test('5. PaymentMethod enum maps English DB values and Arabic display names', () {
      expect(PaymentMethod.fromString('cash'), equals(PaymentMethod.cash));
      expect(PaymentMethod.cash.dbValue, equals('cash'));

      expect(PaymentMethod.fromString('card'), equals(PaymentMethod.card));
      expect(PaymentMethod.card.dbValue, equals('card'));

      expect(PaymentMethod.fromString('transfer'), equals(PaymentMethod.transfer));
      expect(PaymentMethod.fromString('insurance'), equals(PaymentMethod.insurance));
    });

    test('6. LabOrderStatus & LabOrderPriority enums map English DB values', () {
      expect(LabOrderStatus.fromString('pending'), equals(LabOrderStatus.pending));
      expect(LabOrderStatus.pending.dbValue, equals('pending'));

      expect(LabOrderStatus.fromString('in_progress'), equals(LabOrderStatus.inProgress));
      expect(LabOrderStatus.inProgress.dbValue, equals('in_progress'));

      expect(LabOrderPriority.fromString('normal'), equals(LabOrderPriority.normal));
      expect(LabOrderPriority.normal.dbValue, equals('normal'));

      expect(LabOrderPriority.fromString('stat'), equals(LabOrderPriority.stat));
      expect(LabOrderPriority.stat.dbValue, equals('stat'));
    });
  });
}
