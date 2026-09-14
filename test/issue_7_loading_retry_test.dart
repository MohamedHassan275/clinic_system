import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:clinic_system/core/common/error_handler/failure.dart';
import 'package:clinic_system/modules/shared/cubit/base_cubit.dart';
import 'package:clinic_system/modules/shared/cubit/block_builder_widget.dart';

enum TestApiType { testOperation }

class TestCubit extends BaseCubit<TestApiType> {
  int executionCount = 0;
  bool shouldFail = true;

  TestCubit() : super(TestApiType.testOperation);

  Future<void> performOperation() async {
    await fastFire(
      type: TestApiType.testOperation,
      fun: () async {
        executionCount++;
        if (shouldFail) {
          return Left(Failure(500, 'فشل الاتصال الخادم'));
        }
        return const Right('نجاح العملية');
      },
      onSuccess: (_) {},
    );
  }
}

void main() {
  group('Issue 7: Error State & Retry Mechanism Unit Tests', () {
    testWidgets('1. Displays error message and triggers retry callback when button is pressed', (tester) async {
      final cubit = TestCubit();

      await cubit.performOperation();
      expect(cubit.stateOf(TestApiType.testOperation).isError(), isTrue);
      expect(cubit.errorMessageOf(TestApiType.testOperation), equals('فشل الاتصال الخادم'));
      expect(cubit.executionCount, equals(1));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: BlockBuilderWidget<TestCubit, TestApiType>(
                types: const [TestApiType.testOperation],
                onRetry: () => cubit.performOperation(),
                body: (_) => const Text('المحتوى الاصلي'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify error screen elements
      expect(find.text('فشل الاتصال الخادم'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      // Change state to succeed and tap retry button
      cubit.shouldFail = false;
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();

      expect(cubit.executionCount, equals(2));
      expect(cubit.stateOf(TestApiType.testOperation).isDone(), isTrue);
      expect(find.text('المحتوى الاصلي'), findsOneWidget);

      await cubit.close();
    });

    testWidgets('2. Automatic cubit.retry re-executes fastFire closure without explicit onRetry prop', (tester) async {
      final cubit = TestCubit();

      await cubit.performOperation();
      expect(cubit.executionCount, equals(1));
      expect(cubit.stateOf(TestApiType.testOperation).isError(), isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: BlockBuilderWidget<TestCubit, TestApiType>(
                types: const [TestApiType.testOperation],
                body: (_) => const Text('تم جلب البيانات بنجاح'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      cubit.shouldFail = false;
      await cubit.retry(TestApiType.testOperation);
      await tester.pumpAndSettle();

      expect(cubit.executionCount, equals(2));
      expect(cubit.stateOf(TestApiType.testOperation).isDone(), isTrue);
      expect(find.text('تم جلب البيانات بنجاح'), findsOneWidget);

      await cubit.close();
    });
  });
}
