// lib/widgets/backup_modal.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/backup_service_plus.dart';
import '../utils/date_helper.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../widgets/gradient_button.dart';
import '../widgets/modern_card.dart';

class BackupModal extends StatefulWidget {
  final Function? onBackupRealizado;

  const BackupModal({super.key, this.onBackupRealizado});

  @override
  State<BackupModal> createState() => _BackupModalState();

  static Future<void> show({
    required BuildContext context,
    Function? onBackupRealizado,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: BackupModal(onBackupRealizado: onBackupRealizado),
      ),
    );
  }
}

class _BackupModalState extends State<BackupModal> {
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
    final nome = file.path.split('\\').last;
    final dataDoNome = DateHelper.dataDoNomeArquivo(nome);
    if (dataDoNome != null) {
      return DateFormat('dd/MM/yyyy HH:mm').format(dataDoNome);
    }
    final stat = file.statSync();
    return DateHelper.formatarDataBrasil(stat.modified, comHora: true);
  }

  String _formatarTamanho(File file) {
    final bytes = file.statSync().size;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _fazerBackup() async {
    final caminho = await _backupService.salvarBackupEmArquivo();
    if (caminho != null && context.mounted) {
      await _carregarBackups();
      widget.onBackupRealizado?.call();
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

  Future<void> _restaurarBackup(File backup) async {
    final nome = backup.path.split('\\').last;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
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
              'Você está prestes a restaurar:',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
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
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.red, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Todos os dados atuais serão SUBSTITUÍDOS!',
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
        widget.onBackupRealizado?.call();
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
      if (mounted) setState(() => carregando = false);
    }
  }

  Future<void> _excluirBackup(File backup) async {
    final nome = backup.path.split('\\').last;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
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
                color: AppColors.muted(context).withOpacity(0.1),
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
        widget.onBackupRealizado?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.delete, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('🗑️ Backup excluído')),
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
    return Column(
      children: [
        // 🔝 CABEÇALHO
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              const Text(
                'Backup e Restauração',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // 📝 CONTEÚDO
        Expanded(
          child: carregando
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Botão de backup
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: GradientButton(
                          text: 'FAZER BACKUP AGORA',
                          icon: Icons.backup,
                          onPressed: _fazerBackup,
                        ),
                      ),

                      // Lista de backups
                      if (backups.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.cloud_off,
                                size: 48,
                                color: AppColors.muted(context),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Nenhum backup encontrado',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...backups.map((backup) {
                          final nome = backup.path.split('\\').last;
                          final isMaisRecente = backup == backups.first;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ModernCard(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // Ícone
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        gradient: isMaisRecente
                                            ? const LinearGradient(
                                                colors: [
                                                  AppColors.primary,
                                                  AppColors.secondary
                                                ],
                                              )
                                            : null,
                                        color: isMaisRecente
                                            ? null
                                            : AppColors.muted(context)
                                                .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        isMaisRecente
                                            ? Icons.star
                                            : Icons.backup,
                                        color: isMaisRecente
                                            ? Colors.white
                                            : AppColors.primary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Informações
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            nome,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: AppColors.textPrimary(
                                                  context),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_today,
                                                  size: 12,
                                                  color:
                                                      AppColors.textSecondary(
                                                          context)),
                                              const SizedBox(width: 4),
                                              Text(
                                                _formatarData(backup),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      AppColors.textSecondary(
                                                          context),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Icon(Icons.data_usage,
                                                  size: 12,
                                                  color:
                                                      AppColors.textSecondary(
                                                          context)),
                                              const SizedBox(width: 4),
                                              Text(
                                                _formatarTamanho(backup),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      AppColors.textSecondary(
                                                          context),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Ações
                                    Row(
                                      children: [
                                        // Restaurar
                                        Container(
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.green.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: IconButton(
                                            icon: const Icon(Icons.restore,
                                                color: Colors.green, size: 20),
                                            onPressed: () =>
                                                _restaurarBackup(backup),
                                            tooltip: 'Restaurar',
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        // Excluir
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red, size: 20),
                                            onPressed: () =>
                                                _excluirBackup(backup),
                                            tooltip: 'Excluir',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
