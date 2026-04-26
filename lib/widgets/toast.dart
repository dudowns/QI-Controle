// lib/widgets/toast.dart
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum ToastType { success, error, warning, info }

class Toast {
  static void show({
    required BuildContext context,
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 2),
  }) {
    final colors = {
      ToastType.success: AppColors.success,
      ToastType.error: AppColors.error,
      ToastType.warning: AppColors.warning,
      ToastType.info: AppColors.info,
    };

    final icons = {
      ToastType.success: Icons.check_circle,
      ToastType.error: Icons.error_outline,
      ToastType.warning: Icons.warning_amber,
      ToastType.info: Icons.info_outline,
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icons[type], color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: colors[type],
        behavior: SnackBarBehavior.floating,
        duration: duration,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  static void success(BuildContext context, String message) {
    show(context: context, message: message, type: ToastType.success);
  }

  static void error(BuildContext context, String message) {
    show(context: context, message: message, type: ToastType.error);
  }

  static void warning(BuildContext context, String message) {
    show(context: context, message: message, type: ToastType.warning);
  }

  static void info(BuildContext context, String message) {
    show(context: context, message: message, type: ToastType.info);
  }
}
