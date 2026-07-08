// lib/providers/layout_provider.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum LayoutMode { mobile, desktop }

class LayoutProvider extends ChangeNotifier {
  LayoutMode _mode = LayoutMode.mobile;
  bool _forceMode = false;
  double _screenWidth = 600;

  LayoutMode get mode => _mode;
  bool get isMobile => _mode == LayoutMode.mobile;
  bool get isDesktop => _mode == LayoutMode.desktop;
  bool get isForced => _forceMode;

  void setMode(LayoutMode mode) {
    if (_mode != mode) {
      _mode = mode;
      _forceMode = true;
      notifyListeners();
    }
  }

  void setAutoMode() {
    _forceMode = false;
    _mode = _screenWidth < 900 ? LayoutMode.mobile : LayoutMode.desktop;
    notifyListeners();
  }

  void toggleMode() {
    setMode(
        _mode == LayoutMode.mobile ? LayoutMode.desktop : LayoutMode.mobile);
  }

  // ✅ MÉTODO CORRIGIDO: Agora existe!
  void updateScreenSize(double width) {
    _screenWidth = width;
    if (!_forceMode) {
      final newMode = width < 900 ? LayoutMode.mobile : LayoutMode.desktop;
      if (_mode != newMode) {
        _mode = newMode;
        notifyListeners();
      }
    }
  }

  static LayoutProvider of(BuildContext context) {
    return Provider.of<LayoutProvider>(context, listen: false);
  }

  static LayoutProvider watch(BuildContext context) {
    return Provider.of<LayoutProvider>(context);
  }
}
