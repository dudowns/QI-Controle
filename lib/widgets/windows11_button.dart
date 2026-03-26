// lib/widgets/windows11_button.dart (já existe, mas vamos garantir)
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class Windows11Button extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? width;
  final double? height;
  final bool isOutlined;
  final IconData? icon;
  final bool isFullWidth;
  final double borderRadius;

  const Windows11Button({
    super.key,
    required this.text,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.width,
    this.height,
    this.isOutlined = false,
    this.icon,
    this.isFullWidth = false,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle = isOutlined
        ? OutlinedButton.styleFrom(
            foregroundColor: foregroundColor ?? AppColors.primary,
            side: BorderSide(color: foregroundColor ?? AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            minimumSize: isFullWidth
                ? const Size(double.infinity, 40)
                : Size(width ?? 70, height ?? 32),
            padding: EdgeInsets.zero,
          )
        : ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? AppColors.primary,
            foregroundColor: foregroundColor ?? Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            minimumSize: isFullWidth
                ? const Size(double.infinity, 40)
                : Size(width ?? 70, height ?? 32),
            padding: EdgeInsets.zero,
            elevation: 0,
          );

    if (icon != null) {
      return isOutlined
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(text),
              style: buttonStyle,
            )
          : ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(text),
              style: buttonStyle,
            );
    }

    return isOutlined
        ? OutlinedButton(
            onPressed: onPressed,
            style: buttonStyle,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        : ElevatedButton(
            onPressed: onPressed,
            style: buttonStyle,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
  }
}
