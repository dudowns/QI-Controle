// lib/services/loading_service.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Serviço global para gerenciar loading states
class LoadingService extends ChangeNotifier {
  static final LoadingService _instance = LoadingService._internal();
  factory LoadingService() => _instance;
  LoadingService._internal();

  int _loadingCount = 0;

  bool get isLoading => _loadingCount > 0;

  void show() {
    _loadingCount++;
    notifyListeners();
  }

  void hide() {
    if (_loadingCount > 0) {
      _loadingCount--;
      notifyListeners();
    }
  }

  Future<T> run<T>(Future<T> Function() operation) async {
    show();
    try {
      return await operation();
    } finally {
      hide();
    }
  }

  void reset() {
    _loadingCount = 0;
    notifyListeners();
  }
}

/// Widget para mostrar loading overlay global
class GlobalLoadingOverlay extends StatelessWidget {
  final Widget child;
  final Widget? loadingWidget;

  const GlobalLoadingOverlay({
    super.key,
    required this.child,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LoadingService>(
      builder: (context, loadingService, _) {
        return Stack(
          children: [
            child,
            if (loadingService.isLoading)
              Container(
                color: Colors.black.withValues(alpha:0.5),
                child: Center(
                  child: loadingWidget ??
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha:0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Carregando...',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                ),
              ),
          ],
        );
      },
    );
  }
}

