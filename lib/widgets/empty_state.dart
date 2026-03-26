import 'package:flutter/material.dart';
import '../constants/app_sizes.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? buttonText;
  final VoidCallback? onButtonPressed;

  const EmptyState({
    super.key,
    this.icon = Icons.inbox,
    required this.message,
    this.buttonText,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: AppSizes.paddingL),
          Text(message, textAlign: TextAlign.center),
          if (buttonText != null && onButtonPressed != null) ...[
            const SizedBox(height: AppSizes.paddingL),
            ElevatedButton(
                onPressed: onButtonPressed, child: Text(buttonText!)),
          ],
        ],
      ),
    );
  }
}
