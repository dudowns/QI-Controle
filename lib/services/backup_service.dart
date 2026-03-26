import 'dart:io'; // 🔥 ESSENCIAL!
import 'package:path_provider/path_provider.dart';
// Adicionar no início:
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../widgets/primary_card.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/empty_state.dart';
import '../utils/formatters.dart';

class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  final String pastaBackup =
      r'C:\Users\anaep\OneDrive\Documentos\Contas\BackupFinanceiro';

  Future<void> init() async {
    final directory = Directory(pastaBackup);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      print('✅ Pasta de backup criada: $pastaBackup');
    }
  }

  Future<bool> fazerBackup() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final origem = File('${appDir.path}/financeiro.db');

      if (!await origem.exists()) {
        print('ℹ️ Banco ainda não existe');
        return false;
      }

      final data = DateTime.now();
      final nomeArquivo =
          'backup_${data.year.toString().padLeft(4, '0')}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}.db';
      final destino = File('$pastaBackup/$nomeArquivo');

      await Directory(pastaBackup).create(recursive: true);
      await destino.writeAsBytes(await origem.readAsBytes());

      await _limparBackupsAntigos();

      print('✅ Backup criado: $destino');
      return true;
    } catch (e) {
      print('❌ Erro no backup: $e');
      return false;
    }
  }

  Future<void> _limparBackupsAntigos() async {
    try {
      final directory = Directory(pastaBackup);
      if (!await directory.exists()) return;

      final arquivos = await directory
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.db'))
          .toList();

      if (arquivos.length <= 30) return;

      arquivos.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      for (int i = 30; i < arquivos.length; i++) {
        await arquivos[i].delete();
      }
    } catch (e) {
      print('❌ Erro ao limpar backups: $e');
    }
  }

  Future<List<File>> listarBackups() async {
    try {
      final directory = Directory(pastaBackup);
      if (!await directory.exists()) return [];

      final arquivos = await directory
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.db'))
          .toList();

      arquivos.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      return arquivos.cast<File>();
    } catch (e) {
      print('❌ Erro ao listar backups: $e');
      return [];
    }
  }

  Future<bool> restaurarBackup(String caminhoBackup) async {
    try {
      final backup = File(caminhoBackup);
      if (!await backup.exists()) return false;

      final appDir = await getApplicationSupportDirectory();
      final destino = File('${appDir.path}/financeiro.db');

      await destino.writeAsBytes(await backup.readAsBytes());
      print('✅ Backup restaurado: $caminhoBackup');
      return true;
    } catch (e) {
      print('❌ Erro ao restaurar: $e');
      return false;
    }
  }
}
