// lib/widgets/confirm_dialog.dart
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ConfirmDialog {
  static BuildContext? _cachedContext;

  static void setContext(BuildContext context) {
    _cachedContext = context;
  }

  static BuildContext _getContext() {
    if (_cachedContext == null) {
      throw Exception(
          'ConfirmDialog context not set. Call ConfirmDialog.setContext() in main.dart');
    }
    return _cachedContext!;
  }

  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirmar',
    String cancelText = 'Cancelar',
    Color? confirmColor,
    IconData? icon,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                if (icon != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (confirmColor ?? AppColors.primary)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon,
                        color: confirmColor ?? AppColors.primary, size: 20),
                  ),
                if (icon != null) const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              message,
              style: TextStyle(
                  color: isDark ? Colors.grey[300] : const Color(0xFF666666)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(cancelText,
                    style: TextStyle(color: isDark ? Colors.grey[400] : null)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor ?? AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(confirmText),
              ),
            ],
          ),
        ) ??
        false;
  }

  static Future<bool> delete(String name) async {
    return show(
      context: _getContext(),
      title: 'Excluir',
      message: 'Deseja excluir "$name"?\n\nEsta ação não pode ser desfeita.',
      confirmText: 'EXCLUIR',
      confirmColor: AppColors.error,
      icon: Icons.delete_outline,
    );
  }

  static Future<bool> save(String name) async {
    return show(
      context: _getContext(),
      title: 'Salvar',
      message: 'Deseja salvar as alterações em "$name"?',
      confirmText: 'SALVAR',
      confirmColor: AppColors.success,
      icon: Icons.save,
    );
  }

  static Future<bool> warning({
    required String title,
    required String message,
    String confirmText = 'CONTINUAR',
  }) async {
    return show(
      context: _getContext(),
      title: title,
      message: message,
      confirmText: confirmText,
      confirmColor: AppColors.warning,
      icon: Icons.warning_amber,
    );
  }
}
