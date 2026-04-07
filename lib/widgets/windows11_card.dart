// lib/widgets/windows11_card.dart
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class Windows11Card extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final double elevation;
  final double borderRadius;
  final bool hasBorder;

  const Windows11Card({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.elevation = 0.5,
    this.borderRadius = 12,
    this.hasBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Ink(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white,
            borderRadius: BorderRadius.circular(borderRadius),
            border: hasBorder ? Border.all(color: Colors.grey.shade200) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:0.05 * elevation),
                blurRadius: 8 * elevation,
                offset: Offset(0, 2 * elevation),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class Windows11GradientCard extends StatelessWidget {
  final Widget child;
  final Gradient gradient;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const Windows11GradientCard({
    super.key,
    required this.child,
    required this.gradient,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 12,
  });

  factory Windows11GradientCard.primary({required Widget child}) {
    return Windows11GradientCard(
      gradient: const LinearGradient(
        colors: [AppColors.primary, AppColors.secondary],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

