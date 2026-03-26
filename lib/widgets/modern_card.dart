// lib/widgets/modern_card.dart
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

class ModernCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final bool hasShadow;
  final bool isRounded;

  const ModernCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.padding,
    this.height,
    this.hasShadow = true,
    this.isRounded = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: isRounded
            ? BorderRadius.circular(12)
            : null, // ✅ Usando valor direto se AppSizes não existir
        child: Container(
          height: height,
          padding: padding ?? const EdgeInsets.all(16), // ✅ Padding direto
          decoration: BoxDecoration(
            color: color ??
                Colors
                    .white, // ✅ CORRIGIDO: usar Colors.white em vez de AppColors.cardBackground
            borderRadius: isRounded ? BorderRadius.circular(12) : null,
            boxShadow: hasShadow
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: const Color(0xFF9C27B0).withOpacity(
                          0.02), // ✅ CORRIGIDO: usando primary direto
                      blurRadius: 20,
                      offset: const Offset(0, -2),
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
