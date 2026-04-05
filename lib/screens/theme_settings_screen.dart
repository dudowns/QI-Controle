// lib/screens/theme_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../constants/app_colors.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tema do App'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              isDark ? const Color(0xFF1A1A1A) : Colors.white,
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Card de preview
            Card(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            themeService.themeIcon,
                            color: AppColors.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tema atual',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).brightness ==
                                          Brightness.light
                                      ? Colors.grey[600]
                                      : Colors.grey[400],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                themeService.themeName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Opções de tema
            Card(
              child: Column(
                children: [
                  // 🌞 Claro
                  _buildThemeOption(
                    context: context,
                    theme: AppTheme.light,
                    icon: Icons.wb_sunny,
                    color: Colors.orange,
                    title: 'Claro',
                    subtitle: 'Tema claro padrão',
                    themeService: themeService,
                  ),
                  const Divider(height: 0),

                  // 🌙 Escuro
                  _buildThemeOption(
                    context: context,
                    theme: AppTheme.dark,
                    icon: Icons.nightlight_round,
                    color: Colors.indigo,
                    title: 'Escuro',
                    subtitle: 'Tema noturno para poupar a vista',
                    themeService: themeService,
                  ),
                  const Divider(height: 0),

                  // 🔄 Automático
                  _buildThemeOption(
                    context: context,
                    theme: AppTheme.system,
                    icon: Icons.sync,
                    color: Colors.green,
                    title: 'Automático',
                    subtitle: 'Segue o tema do sistema',
                    themeService: themeService,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Preview dos temas
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🎨 Prévia',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Tema claro
                        Expanded(
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.wb_sunny, color: Colors.orange[300]),
                                const SizedBox(height: 4),
                                Text(
                                  'Claro',
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Tema escuro
                        Expanded(
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[800]!),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.nightlight_round,
                                    color: Colors.indigo[200]),
                                const SizedBox(height: 4),
                                const Text(
                                  'Escuro',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required AppTheme theme,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required ThemeService themeService,
  }) {
    final isSelected = themeService.currentTheme == theme;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: isSelected
          ? Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 16,
              ),
            )
          : null,
      onTap: () => themeService.setTheme(theme),
    );
  }
}
