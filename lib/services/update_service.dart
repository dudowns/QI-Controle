// lib/services/update_service.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  final _supabase = Supabase.instance.client;

  // Verificar se tem atualização disponível
  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentCode = int.parse(packageInfo.buildNumber);

      final response = await _supabase
          .from('app_updates')
          .select()
          .gt('version_code', currentCode)
          .order('version_code', ascending: false)
          .limit(1);

      if (response.isEmpty) return null;
      return response.first;
    } catch (e) {
      print('Erro ao verificar: $e');
      return null;
    }
  }

  // Mostrar diálogo de atualização
  void showUpdateDialog(BuildContext context, Map<String, dynamic> update) {
    final forceUpdate = update['force_update'] ?? false;

    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Colors.orange),
            const SizedBox(width: 10),
            Text('Nova versão ${update['version_name']} disponível!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (update['release_notes'] != null) Text(update['release_notes']),
            const SizedBox(height: 10),
            Text(
              'Versão atual: ${update['version_code'] - 1} → ${update['version_code']}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (forceUpdate)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  '⚠️ Esta atualização é OBRIGATÓRIA!',
                  style:
                      TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        actions: [
          if (!forceUpdate)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Depois'),
            ),
          ElevatedButton(
            onPressed: () => _downloadAndInstall(update['download_url']),
            child: const Text('ATUALIZAR AGORA'),
          ),
        ],
      ),
    );
  }

  // Baixar e instalar
  Future<void> _downloadAndInstall(String url) async {
    try {
      if (await canLaunch(url)) {
        await launch(url);
      }
    } catch (e) {
      print('Erro ao abrir link: $e');
    }
  }
}
