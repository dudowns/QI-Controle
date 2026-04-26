// lib/screens/backup_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/backup_service_plus.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../widgets/gradient_button.dart';
import '../widgets/modern_card.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final BackupServicePlus _backupService = BackupServicePlus();
  List<File> backups = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarBackups();
  }

  Future<void> _carregarBackups() async {
    setState(() => carregando = true);
    backups = await _backupService.listarBackups();
    setState(() => carregando = false);
  }

  String _formatarData(File file) {
    final nome = file.path.split(RegExp(r'[\\/]')).last;
    final dataDoNome = _dataDoNomeArquivo(nome);
    if (dataDoNome != null) {
      return DateFormat('dd/MM/yyyy HH:mm').format(dataDoNome);
    }
    final stat = file.statSync();
    return DateFormat('dd/MM/yyyy HH:mm').format(stat.modified);
  }

  DateTime? _dataDoNomeArquivo(String nomeArquivo) {
    final regex = RegExp(r'backup_(\d+)\.json');
    final match = regex.firstMatch(nomeArquivo);
    if (match != null) {
      final timestamp = int.parse(match.group(1)!);
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  String _formatarTamanho(File file) {
    final bytes = file.statSync().size;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // 🟢 FUNCAO PARA FAZER BACKUP
  Future<void> _fazerBackup() async {
    final caminho = await _backupService.salvarBackupEmArquivo();
    if (caminho != null && context.mounted) {
      await _carregarBackups();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('✅ Backup realizado com sucesso!')),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // 🟢 FUNCAO PARA RESTAURAR BACKUP
  Future<void> _restaurarBackupSelecionado() async {
    if (backups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('⚠️ Nenhum backup encontrado!')),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (backups.length == 1) {
      _confirmarRestauracao(backups.first);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: Row(
          children: [
            const Icon(Icons.restore, color: Colors.orange),
            const SizedBox(width: 12),
            Text(
              'Selecione o Backup',
              style: TextStyle(color: AppColors.textPrimary(context)),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: backups.length,
            itemBuilder: (context, index) {
              final backup = backups[index];
              final nome = backup.path.split(RegExp(r'[\\/]')).last;
              final isMaisRecente = index == 0;

              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMaisRecente
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.muted(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isMaisRecente ? Icons.star : Icons.backup,
                    color: isMaisRecente
                        ? AppColors.primary
                        : AppColors.textSecondary(context),
                  ),
                ),
                title: Text(
                  nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textPrimary(context)),
                ),
                subtitle: Text(
                  '📅 ${_formatarData(backup)} • 💾 ${_formatarTamanho(backup)}',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary(context)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmarRestauracao(backup);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ),
        ],
      ),
    );
  }

  // 🟢 CONFIRMAR RESTAURACAO
  Future<void> _confirmarRestauracao(File backup) async {
    final nome = backup.path.split(RegExp(r'[\\/]')).last;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.restore, color: Colors.orange),
            ),
            const SizedBox(width: 12),
            Text(
              'Restaurar Backup',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voce esta prestes a restaurar:',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.backup, color: Colors.orange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 12,
                                color: AppColors.textSecondary(context)),
                            const SizedBox(width: 4),
                            Text(
                              _formatarData(backup),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary(context)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.red, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Todos os dados atuais serao SUBSTITUIDOS!',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('RESTAURAR'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => carregando = true);

    try {
      final sucesso = await _backupService.restaurarBackup(
        backup.path,
        limparAntes: true,
      );

      if (sucesso && mounted) {
        await _carregarBackups();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('✅ Backup restaurado com sucesso!')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('❌ Erro ao restaurar: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => carregando = false);
      }
    }
  }

  // 🟢 FUNCAO PARA EXCLUIR BACKUP
  Future<void> _excluirBackup(File backup) async {
    final nome = backup.path.split(RegExp(r'[\\/]')).last;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete, color: Colors.red),
            ),
            const SizedBox(width: 12),
            Text(
              'Excluir Backup',
              style: TextStyle(color: AppColors.textPrimary(context)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Deseja excluir o backup:',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.muted(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.backup, color: AppColors.textSecondary(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      nome,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await backup.delete();
      if (mounted) {
        await _carregarBackups();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.delete, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('🗑️ Backup excluido')),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.backup, color: Colors.white),
            SizedBox(width: 12),
            Text('Backup e Restauracao'),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarBackups,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background(context),
              AppColors.surface(context),
            ],
          ),
        ),
        child: carregando
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Carregando backups...',
                      style: TextStyle(color: AppColors.textSecondary(context)),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ModernCard(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.cloud_upload,
                                    color: AppColors.primary,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Proteja seus dados',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary(context),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Faca backup e restaure quando precisar',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              AppColors.textSecondary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: GradientButton(
                                text: 'FAZER BACKUP AGORA',
                                icon: Icons.backup,
                                onPressed: _fazerBackup,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.restore,
                                    color: Colors.white),
                                label: const Text(
                                  'RESTAURAR BACKUP EXISTENTE',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: _restaurarBackupSelecionado,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: backups.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: AppColors.muted(context)
                                        .withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.cloud_off,
                                    size: 48,
                                    color: AppColors.muted(context),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Nenhum backup encontrado',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Clique em "FAZER BACKUP AGORA" para comecar',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: backups.length,
                            itemBuilder: (context, index) {
                              final backup = backups[index];
                              final nome =
                                  backup.path.split(RegExp(r'[\\/]')).last;
                              final isMaisRecente = index == 0;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ModernCard(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            gradient: isMaisRecente
                                                ? const LinearGradient(
                                                    colors: [
                                                      AppColors.primary,
                                                      AppColors.secondary,
                                                    ],
                                                  )
                                                : null,
                                            color: isMaisRecente
                                                ? null
                                                : AppColors.muted(context)
                                                    .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            isMaisRecente
                                                ? Icons.star
                                                : Icons.backup,
                                            color: isMaisRecente
                                                ? Colors.white
                                                : AppColors.primary,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      nome,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                        color: isMaisRecente
                                                            ? AppColors.primary
                                                            : AppColors
                                                                .textPrimary(
                                                                    context),
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (isMaisRecente)
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.primary
                                                            .withValues(
                                                                alpha: 0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      child: const Text(
                                                        'MAIS RECENTE',
                                                        style: TextStyle(
                                                          fontSize: 8,
                                                          color:
                                                              AppColors.primary,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(Icons.calendar_today,
                                                      size: 12,
                                                      color: AppColors
                                                          .textSecondary(
                                                              context)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _formatarData(backup),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors
                                                          .textSecondary(
                                                              context),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Icon(Icons.data_usage,
                                                      size: 12,
                                                      color: AppColors
                                                          .textSecondary(
                                                              context)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _formatarTamanho(backup),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors
                                                          .textSecondary(
                                                              context),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.red
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red, size: 22),
                                            onPressed: () =>
                                                _excluirBackup(backup),
                                            tooltip: 'Excluir backup',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
