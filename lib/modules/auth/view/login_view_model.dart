import 'package:flutter/material.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/security/session_manager.dart';
import '../data/cubit/auth_cubit.dart';

class LoginViewModel extends BaseViewModel {
  final AuthCubit authCubit;

  LoginViewModel(super.reLoad, this.authCubit);

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isPasswordVisible = false;
  bool isOnlineMode = false;

  void togglePasswordVisibility() {
    isPasswordVisible = !isPasswordVisible;
    refresh();
  }

  void toggleOnlineMode(bool value) {
    isOnlineMode = value;
    SessionManager.instance.setOnlineMode(value);
    refresh();
  }

  Future<void> submitLogin({
    required VoidCallback onSuccess,
    required Function(String errorMessage) onError,
  }) async {
    final username = usernameController.text;
    final password = passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      onError('يرجى كتابة اسم المستخدم وكلمة المرور');
      return;
    }

    final result = await authCubit.login(username: username, password: password);
    result.fold(
      (failure) => onError(failure.message),
      (userMap) {
        SessionManager.instance.setUserSession(userMap);
        SessionManager.instance.setOnlineMode(isOnlineMode);
        onSuccess();
      },
    );
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    authCubit.close();
    super.dispose();
  }
}
