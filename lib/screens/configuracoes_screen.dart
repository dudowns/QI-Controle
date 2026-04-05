import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';

class ConfiguracoesScreen extends StatelessWidget {
  const ConfiguracoesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Configurações'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Perfil
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Perfil'),
              subtitle: Text(auth.usuarioAtual?.email ?? ''),
              onTap: () {},
            ),
          ),
          // Tema
          Card(
            child: ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('Tema'),
              subtitle: const Text('Claro / Escuro / Automático'),
              onTap: () {},
            ),
          ),
          // Backup
          Card(
            child: ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Backup'),
              subtitle: const Text('Exportar / Importar dados'),
              onTap: () {},
            ),
          ),
          // Sobre
          Card(
            child: ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Sobre'),
              subtitle: const Text('Versão 2.0'),
              onTap: () {},
            ),
          ),
          const Divider(),
          // Logout
          Card(
            color: Colors.red.shade50,
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Sair',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                await auth.logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (route) => false);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
