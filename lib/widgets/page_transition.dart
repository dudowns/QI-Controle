// lib/widgets/page_transition.dart
import 'package:flutter/material.dart';

class PageTransition {
  // Animação 1: Deslizar da direita (padrão)
  static Route<T> slideFromRight<T>(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: offsetAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  // Animação 2: Fade + Scale (zoom suave)
  static Route<T> fadeScale<T>(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var tween = Tween(begin: 0.8, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic));
        var scaleAnimation = animation.drive(tween);

        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  // Animação 3: Deslizar de baixo (para modais)
  static Route<T> slideFromBottom<T>(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  // Animação 4: Rotação + Escala (efeito especial)
  static Route<T> rotateScale<T>(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var tween = Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack));
        var rotationAnimation = animation.drive(tween);

        var scaleTween = Tween(begin: 0.5, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic));
        var scaleAnimation = animation.drive(scaleTween);

        return FadeTransition(
          opacity: animation,
          child: Transform.rotate(
            angle: rotationAnimation.value * 0.1,
            child: ScaleTransition(
              scale: scaleAnimation,
              child: child,
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 500),
    );
  }
}
