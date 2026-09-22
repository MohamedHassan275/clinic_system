import 'package:flutter/material.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/security/session_manager.dart';

class SplashViewModel extends BaseViewModel {
  SplashViewModel(super.reLoad);

  Future<void> initializeApp({
    required VoidCallback onGoToSetupWizard,
    required VoidCallback onGoToLogin,
    required VoidCallback onGoToShift,
    required VoidCallback onGoToMainShell,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1000));

    bool isSetupRequired = false;
    try {
      final db = await DatabaseHelper.instance.database;
      await SessionManager.instance.initPersistentSession();

      // Check if DB has any users or clinic records
      final userCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM users');
      final userCount = userCountRes.isNotEmpty ? (userCountRes.first['count'] as int? ?? 0) : 0;
      if (userCount == 0) {
        isSetupRequired = true;
      }
    } catch (e) {
      // If error occurs, fallback to setup
    }

    if (isSetupRequired) {
      onGoToSetupWizard();
      return;
    }

    if (SessionManager.instance.isLoggedIn) {
      onGoToMainShell();
    } else {
      onGoToLogin();
    }
  }
}
