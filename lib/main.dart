import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/di/service_locator.dart';
import 'core/theme/app_theme.dart';
import 'modules/splash/view/splash_screen.dart';

import 'core/sync/sync_service.dart';

void main() async {
  // 1. ضمان تهيئة Flutter Bindings أولاً
  WidgetsFlutterBinding.ensureInitialized();

  // 2. تهيئة الاتصال بالسحاب Supabase
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
    debugPrint('⚡ [Supabase]: Initialized successfully with URL: ${SupabaseConfig.url}');
  } catch (e) {
    debugPrint('🔴 [Supabase Error]: Failed to initialize Supabase: $e');
  }

  // 3. تهيئة حقن الخدمات Service Locator
  await initServiceLocator();

  // 4. تهيئة وتطوير محرك المزامنة اللحظية خلف الكواليس
  try {
    SyncService.instance.init();
    debugPrint('⚡ [SyncService]: Initialized background sync engine.');
  } catch (e) {
    debugPrint('🔴 [SyncService Error]: Failed to initialize SyncService: $e');
  }

  // 5. تشغيل التطبيق
  runApp(const ClinicManagementApp());
}

class ClinicManagementApp extends StatelessWidget {
  const ClinicManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نظام إدارة العيادات الذكي',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
    );
  }
}
