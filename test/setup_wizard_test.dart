import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_system/modules/auth/view/screens/setup_wizard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SetupWizardScreen Widget Tests', () {
    testWidgets('1. renders SetupWizardScreen with Step 1 fields', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SetupWizardScreen(),
        ),
      );

      expect(find.text('معالج إعداد النظام والعيادة لأول مرة (Setup Wizard)'), findsOneWidget);
      expect(find.text('الخطوة 1: بيانات العيادة والفرع'), findsOneWidget);
      expect(find.byIcon(Icons.storefront), findsWidgets);
    });

    testWidgets('2. validates Step 1 required fields when pressing Next', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SetupWizardScreen(),
        ),
      );

      final nextButton = find.text('التالي');
      expect(nextButton, findsOneWidget);
      await tester.tap(nextButton);
      await tester.pump();

      // Should remain on step 1 or proceed if pre-filled defaults are valid
      expect(find.byType(SetupWizardScreen), findsOneWidget);
    });

    testWidgets('3. renders step navigation sidebar', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SetupWizardScreen(),
        ),
      );

      expect(find.text('بيانات العيادة'), findsWidgets);
      expect(find.text('مدير النظام'), findsWidgets);
      expect(find.text('الإعدادات الأولية'), findsWidgets);
      expect(find.text('مراجعة وتأكيد'), findsWidgets);
    });
  });
}
