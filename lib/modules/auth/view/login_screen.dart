import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/enums/user_role.dart';
import '../../../../core/security/session_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../main_shell/view/clinic_main_shell.dart';
import '../../shared/cubit/base_cubit.dart';
import '../../shared/cubit/block_builder_widget.dart';
import '../../shift/view/shift_screen.dart';
import '../data/cubit/auth_cubit.dart';
import 'login_view_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final LoginViewModel _viewModel;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _viewModel = sl<LoginViewModel>()..updateRefresh(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _handlePostLoginNavigation() {
    final user = SessionManager.instance.currentUser;
    final role = UserRole.fromString(user?['role']);

    if (role == UserRole.doctor || role == UserRole.superAdmin) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ClinicMainShell()),
      );
    } else {
      // Secretary / Receptionist: Check active shift
      if (SessionManager.instance.hasActiveShift) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ClinicMainShell()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ShiftScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocProvider.value(
        value: _viewModel.authCubit,
        child: BlocListener<AuthCubit, BaseState<AuthApiType>>(
          listenWhen: (_, state) => state.type == AuthApiType.login,
          listener: (context, state) {
            final cubit = context.read<AuthCubit>();
            final currentState = cubit.stateOf(AuthApiType.login);
            if (currentState.isDone()) {
              final user = SessionManager.instance.currentUser;
              final role = UserRole.fromString(user?['role']);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('مرحباً بك! تم التعرف على الدور: ${role.displayName}'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isDesktop = constraints.maxWidth >= 900;
              if (isDesktop) {
                return Row(
                  children: [
                    // Right Pane: Branding & Medical Visual (50%)
                    Expanded(
                      flex: 1,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.sidebarBackground, Color(0xFF1E3A8A)],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                        ),
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.local_hospital, size: 64, color: AppColors.accent),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'نظام إدارة العيادات الذكي',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'منظومة متكاملة متخصصة للعيادات والمراكز الطبية بتجربة موجهة حسب دور المستخدم (Doctor Portal & Secretary Portal).',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 40),
                            _buildFeatureCheck('التعرف الآلي على الدور (Doctor / Secretary / Admin)'),
                            const SizedBox(height: 12),
                            _buildFeatureCheck('روشتة إلكترونية وقوالب علاجية متطورة'),
                            const SizedBox(height: 12),
                            _buildFeatureCheck('قاعدة بيانات مشفرة وسريعة تعمل بدون إنترنت'),
                          ],
                        ),
                      ),
                    ),
                    // Left Pane: Login Form (50%)
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(48),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: _buildLoginForm(),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                // Mobile Layout: Compact Single Column
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.local_hospital, size: 56, color: AppColors.primary),
                        const SizedBox(height: 12),
                        const Text(
                          'نظام إدارة العيادات الذكي',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: _buildLoginForm(),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCheck(String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: AppColors.accent, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تسجيل الدخول للنظام',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'أدخل بيانات حسابك للمتابعة والوصول للبوابة الخاصة بك',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _viewModel.usernameController,
            decoration: const InputDecoration(
              labelText: 'اسم المستخدم',
              hintText: 'أدخل اسم المستخدم الخاص بك',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'يرجى إدخال اسم المستخدم' : null,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _viewModel.passwordController,
            obscureText: !_viewModel.isPasswordVisible,
            decoration: InputDecoration(
              labelText: 'كلمة المرور',
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _viewModel.isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: _viewModel.togglePasswordVisibility,
              ),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'يرجى إدخال كلمة المرور' : null,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يرجى التواصل مع مسؤول النظام لإعادة ضبط كلمة المرور.'),
                  ),
                );
              },
              child: const Text('هل نسيت كلمة المرور؟', style: TextStyle(color: AppColors.secondary)),
            ),
          ),
          const SizedBox(height: 24),
          BlockBuilderWidget<AuthCubit, AuthApiType>(
            types: const [AuthApiType.login],
            body: (_) => _buildSubmitButton(),
            error: (_) => _buildSubmitButton(),
            loading: (_) => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          _viewModel.submitLogin(
            onSuccess: _handlePostLoginNavigation,
            onError: (err) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(err),
                  backgroundColor: AppColors.error,
                ),
              );
            },
          );
        },
        child: const Text(
          'تسجيل الدخول',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
