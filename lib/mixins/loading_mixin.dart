// lib/mixins/loading_mixin.dart
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

mixin LoadingMixin<T extends StatefulWidget> on State<T> {
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  @protected
  set isLoading(bool value) {
    if (mounted) {
      setState(() => _isLoading = value);
    }
  }

  Future<TResult> withLoading<TResult>(
      Future<TResult> Function() action) async {
    isLoading = true;
    try {
      return await action();
    } finally {
      isLoading = false;
    }
  }

  Widget buildWithLoading(Widget child, {String? message}) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  if (message != null) ...[
                    const SizedBox(height: 16),
                    Text(message),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// lib/mixins/refresh_mixin.dart
mixin RefreshMixin<T extends StatefulWidget> on State<T> {
  final GlobalKey<RefreshIndicatorState> refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  Future<void> onRefresh() async {
    // Implementar nas classes filhas
  }

  Widget buildRefreshable(Widget child) {
    return RefreshIndicator(
      key: refreshIndicatorKey,
      onRefresh: onRefresh,
      color: AppColors.primary,
      backgroundColor: AppColors.surface(context),
      child: child,
    );
  }

  void showRefreshIndicator() {
    refreshIndicatorKey.currentState?.show();
  }
}

// lib/mixins/confirm_mixin.dart
mixin ConfirmMixin<T extends StatefulWidget> on State<T> {
  Future<bool> showConfirmDialog({
    required String title,
    required String message,
    String confirmText = 'Confirmar',
    String cancelText = 'Cancelar',
    Color confirmColor = AppColors.error,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(cancelText),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(confirmText),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> showDeleteConfirm(String name) async {
    return await showConfirmDialog(
      title: 'Excluir',
      message: 'Deseja excluir "$name"?',
      confirmText: 'EXCLUIR',
    );
  }
}
