import 'package:flutter/material.dart';

class NeumorphicButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool isPressed;

  const NeumorphicButton({
    super.key,
    required this.child,
    this.onPressed,
    this.isPressed = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        boxShadow: isPressed
            ? [
                BoxShadow(
                  color: Colors.grey[400]!,
                  offset: const Offset(2, 2),
                  blurRadius: 4,
                ),
                const BoxShadow(
                  color: Colors.white,
                  offset: Offset(-2, -2),
                  blurRadius: 4,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.grey[500]!,
                  offset: const Offset(4, 4),
                  blurRadius: 8,
                ),
                const BoxShadow(
                  color: Colors.white,
                  offset: Offset(-4, -4),
                  blurRadius: 8,
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: child,
        ),
      ),
    );
  }
}
