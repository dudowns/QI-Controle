// lib/widgets/slide_transition.dart
import 'package:flutter/material.dart';

class SlideTransitionAnimation extends PageRouteBuilder {
  final Widget page;
  final Duration duration;
  final Curve curve;
  final Offset beginOffset;
  final Offset endOffset;

  SlideTransitionAnimation({
    required this.page,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOutCubic,
    this.beginOffset = const Offset(1.0, 0.0),
    this.endOffset = Offset.zero,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var tween = Tween(begin: beginOffset, end: endOffset)
                .chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          transitionDuration: duration,
        );
}

// Animação de fade + scale
class FadeScaleTransition extends PageRouteBuilder {
  final Widget page;
  final Duration duration;

  FadeScaleTransition({
    required this.page,
    this.duration = const Duration(milliseconds: 400),
  }) : super(
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
          transitionDuration: duration,
        );
}
