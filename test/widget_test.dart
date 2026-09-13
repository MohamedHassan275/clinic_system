import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_system/core/di/service_locator.dart';
import 'package:clinic_system/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App smoke test', (WidgetTester tester) async {
    await initServiceLocator();
    await tester.pumpWidget(const ClinicManagementApp());
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(ClinicManagementApp), findsOneWidget);
  });
}
