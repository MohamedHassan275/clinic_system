import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/theme/app_colors.dart';

/// شاشة اختيارية لتجربة واختبار المصادقة السحابية Supabase Auth
class SupabaseAuthTestScreen extends StatefulWidget {
  const SupabaseAuthTestScreen({super.key});

  @override
  State<SupabaseAuthTestScreen> createState() => _SupabaseAuthTestScreenState();
}

class _SupabaseAuthTestScreenState extends State<SupabaseAuthTestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'mohamed@test.com');
  final _passwordController = TextEditingController();

  final _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;
  User? _signedInUser;

  int? _patientsCount;

  @override
  void initState() {
    super.initState();
    // التحقق من وجود جلسة سحابية نشطة بالفعل
    _signedInUser = _authService.currentUser;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. التحقق من توفر الإنترنت أولاً
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        throw Exception('تحقق من الاتصال بالإنترنت أولاً');
      }

      // 2. محاولة تسجيل الدخول عبر Supabase Auth
      final response = await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // 3. اختبار قراءة البيانات من جدول patients السحابي
      int count = 0;
      try {
        final List<dynamic> data = await Supabase.instance.client.from('patients').select();
        count = data.length;
        debugPrint('📊 [Supabase Query Test]: Successfully queried patients table. Total rows: $count');
      } catch (e) {
        debugPrint('⚠️ [Supabase Query Test Error]: $e');
      }

      if (mounted) {
        setState(() {
          _signedInUser = response.user;
          _patientsCount = count;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم تسجيل الدخول السحابي بنجاح!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.message.contains('Invalid login credentials')
              ? 'البريد الإلكتروني أو كلمة المرور غير صحيحة'
              : e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().contains('تحقق من الاتصال')
              ? 'تحقق من الاتصال بالإنترنت'
              : 'حدث خطأ في الاتصال بالخادم: $e';
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    setState(() => _isLoading = true);
    try {
      // يمسح الجلسة السحابية فقط دون التأثير على النظام المحلي
      await _authService.signOut();
      if (mounted) {
        setState(() {
          _signedInUser = null;
          _isLoading = false;
          _errorMessage = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ℹ️ تم تسجيل الخروج السحابي بنجاح'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'فشل تسجيل الخروج: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار المصادقة السحابية (Supabase Auth)'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.cloud_sync_rounded, color: AppColors.primary, size: 28),
                        SizedBox(width: 12),
                        Text(
                          'تجربة الاتصال بـ Supabase',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: AppColors.error, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_signedInUser != null) ...[
                      // كارت تفاصيل الجلسة السحابية الناجحة
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'جلسة سحابية نشطة (Active Session)',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SelectableText('👤 User ID:\n${_signedInUser!.id}', style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 8),
                            SelectableText('📧 Email: ${_signedInUser!.email ?? "غير متاح"}', style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 8),
                            Text('🕒 Last Sign In:\n${_signedInUser!.lastSignInAt ?? "غير متاح"}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            if (_patientsCount != null) ...[
                              const SizedBox(height: 8),
                              Text('📊 Patients Query Test: $_patientsCount records found in Supabase', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isLoading ? null : _handleSignOut,
                        icon: const Icon(Icons.logout_rounded, color: Colors.white),
                        label: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('تسجيل الخروج السحابي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ] else ...[
                      // نموذج بيانات الدخول التجريبية
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'البريد الإلكتروني السحابي',
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'يرجى إدخال البريد الإلكتروني';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'كلمة المرور السحابية',
                                prefixIcon: const Icon(Icons.lock_outline),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) return 'يرجى إدخال كلمة المرور';
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: _isLoading ? null : _handleSignIn,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Icon(Icons.cloud_done_rounded, color: Colors.white),
                                label: Text(
                                  _isLoading ? 'جاري الاتصال بالسحاب...' : 'تسجيل الدخول السحابي',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
