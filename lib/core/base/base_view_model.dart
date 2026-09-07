import 'package:flutter/material.dart';

abstract class BaseViewModel extends ChangeNotifier {
  void Function()? reLoad;

  BaseViewModel([this.reLoad]);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void refresh() {
    reLoad?.call();
    notifyListeners();
  }

  void updateRefresh(void Function() newRefresh) {
    reLoad = newRefresh;
  }

}
