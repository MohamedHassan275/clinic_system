import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/di/service_locator.dart';
import 'core/theme/app_theme.dart';
import 'modules/splash/view/splash_screen.dart';

void main() async {
  // 1. ضمان تهيئة Flutter Bindings أولاً
  WidgetsFlutterBinding.ensureInitialized();

  // 2. تهيئة الاتصال بالسحاب Supabase
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    debugPrint('⚡ [Supabase]: Initialized successfully with URL: ${SupabaseConfig.url}');
  } catch (e) {
    debugPrint('🔴 [Supabase Error]: Failed to initialize Supabase: $e');
  }

  // 3. تهيئة حقن الخدمات Service Locator
  await initServiceLocator();

  // 4. تشغيل التطبيق
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
