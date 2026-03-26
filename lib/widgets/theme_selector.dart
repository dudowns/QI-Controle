// lib/widgets/theme_selector.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../constants/app_colors.dart';

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return PopupMenuButton<AppTheme>(
      icon: Icon(themeService.themeIcon, color: Colors.white),
      tooltip: 'Tema: ${themeService.themeName}',
      color: Theme.of(context).brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      offset: const Offset(0, 40),
      onSelected: (AppTheme theme) {
        themeService.setTheme(theme);
      },
      itemBuilder: (context) => [
        _buildPopupItem(
          context: context,
          theme: AppTheme.light,
          icon: Icons.wb_sunny,
          color: Colors.orange,
          label: 'Claro',
          themeService: themeService,
        ),
        _buildPopupItem(
          context: context,
          theme: AppTheme.dark,
          icon: Icons.nightlight_round,
          color: Colors.indigo,
          label: 'Escuro',
          themeService: themeService,
        ),
        _buildPopupItem(
          context: context,
          theme: AppTheme.system,
          icon: Icons.sync,
          color: Colors.green,
          label: 'Automático',
          themeService: themeService,
        ),
      ],
    );
  }

  PopupMenuItem<AppTheme> _buildPopupItem({
    required BuildContext context,
    required AppTheme theme,
    required IconData icon,
    required Color color,
    required String label,
    required ThemeService themeService,
  }) {
    final isSelected = themeService.currentTheme == theme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuItem(
      value: theme,
      child: Container(
        width: 160,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            // Ícone com fundo
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // Label
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            // Check se selecionado
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
