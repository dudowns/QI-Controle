// lib/utils/modal_helper.dart
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

class ModalHelper {
  // Para diálogos normais (vem de cima)
  static Future<T?> showDialog<T>({
    required BuildContext context,
    required Widget child,
    bool barrierDismissible = true,
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => FadeInDown(
        duration: duration,
        child: child,
      ),
    );
  }

  // Para bottom sheets (vem de baixo)
  static Future<T?> showBottomSheet<T>({
    required BuildContext context,
    required Widget child,
    bool isScrollControlled = true,
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (context) => FadeInUp(
        duration: duration,
        child: child,
      ),
    );
  }
}
