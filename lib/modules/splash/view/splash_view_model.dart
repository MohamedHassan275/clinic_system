import 'package:flutter/material.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/security/session_manager.dart';

class SplashViewModel extends BaseViewModel {
  SplashViewModel(super.reLoad);

  Future<void> initializeApp({
    required VoidCallback onGoToLogin,
    required VoidCallback onGoToShift,
    required VoidCallback onGoToMainShell,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1000));

    try {
      await DatabaseHelper.instance.database;
      await SessionManager.instance.initPersistentSession();
    } catch (e) {
      // Log error
    }

    if (SessionManager.instance.isLoggedIn) {
      if (SessionManager.instance.hasActiveShift) {
        onGoToMainShell();
      } else {
        onGoToShift();
      }
    } else {
      onGoToLogin();
    }
  }
}
