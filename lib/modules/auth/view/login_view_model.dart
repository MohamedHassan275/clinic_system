import 'package:flutter/material.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/enums/database_type.dart';
import '../../../../core/security/session_manager.dart';
import '../data/cubit/auth_cubit.dart';

class LoginViewModel extends BaseViewModel {
  final AuthCubit authCubit;

  LoginViewModel(super.reLoad, this.authCubit);

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isPasswordVisible = false;
  DatabaseType databaseType = DatabaseType.offline;

  bool get isOnlineMode => databaseType != DatabaseType.offline;

  void togglePasswordVisibility() {
    isPasswordVisible = !isPasswordVisible;
    refresh();
  }

  void setDatabaseType(DatabaseType type) {
    if (databaseType == type) return;
    databaseType = type;
    SessionManager.instance.setOnlineMode(type != DatabaseType.offline);
    refresh();
  }

  void toggleOnlineMode(bool value) {
    setDatabaseType(value ? DatabaseType.online : DatabaseType.offline);
  }

  Future<void> submitLogin({
    required VoidCallback onSuccess,
    required Function(String errorMessage) onError,
  }) async {
    final username = usernameController.text.trim();
    final password = passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      onError('يرجى كتابة اسم المستخدم وكلمة المرور');
      return;
    }

    final result = await authCubit.login(
      username: username,
      password: password,
      databaseType: databaseType,
    );
    result.fold(
      (failure) => onError(failure.message),
      (userMap) {
        SessionManager.instance.setUserSession(userMap);
        SessionManager.instance.setOnlineMode(databaseType != DatabaseType.offline);
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
