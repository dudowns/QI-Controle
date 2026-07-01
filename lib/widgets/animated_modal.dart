// lib/widgets/animated_modal.dart
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

class AnimatedModal {
  // Efeito de fade + scale (padrão)
  static Future<T?> showFadeScale<T>({
    required BuildContext context,
    required Widget child,
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => FadeInDown(
        duration: duration,
        child: child, // 🔥 REMOVI O ScaleIn
      ),
    );
  }

  // Efeito de slide de baixo para cima
  static Future<T?> showSlideUp<T>({
    required BuildContext context,
    required Widget child,
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => SlideInUp(
        duration: duration,
        child: child,
      ),
    );
  }

  // Efeito de zoom bounce
  static Future<T?> showBounce<T>({
    required BuildContext context,
    required Widget child,
    Duration duration = const Duration(milliseconds: 500),
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => ZoomIn(
        duration: duration,
        child: child,
      ),
    );
  }
}
