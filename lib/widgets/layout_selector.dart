// lib/widgets/layout_selector.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/layout_provider.dart';
import '../constants/app_colors.dart';

class LayoutSelector extends StatelessWidget {
  const LayoutSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LayoutProvider>(
      builder: (context, layoutProvider, child) {
        final isMobile = layoutProvider.isMobile;
        final isForced = layoutProvider.isForced;

        return Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildButton(
                icon: Icons.phone_android_rounded,
                isSelected: isMobile && isForced,
                onTap: () => layoutProvider.setMode(LayoutMode.mobile),
                tooltip: 'Modo Mobile',
              ),
              _buildButton(
                icon: Icons.desktop_windows_rounded,
                isSelected: !isMobile && isForced,
                onTap: () => layoutProvider.setMode(LayoutMode.desktop),
                tooltip: 'Modo Desktop',
              ),
              _buildButton(
                icon: Icons.devices_rounded,
                isSelected: !isForced,
                onTap: () => layoutProvider.setAutoMode(),
                tooltip: 'Modo Automático',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}
