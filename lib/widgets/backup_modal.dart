// lib/widgets/backup_modal.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/backup_service_plus.dart';
import '../utils/date_helper.dart';
import '../constants/app_colors.dart';
import 'gradient_button.dart';
import 'modern_card.dart';

class BackupModal extends StatefulWidget {
  final Function? onBackupRealizado;

  const BackupModal({super.key, this.onBackupRealizado});

  @override
  State<BackupModal> createState() => _BackupModalState();

  static Future<void> show({
    required BuildContext context,
    Function? onBackupRealizado,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        backgroundColor: Colors.transparent,
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
    if (caminho != null && mounted) {
      await _carregarBackups();
      widget.onBackupRealizado?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('✅ Backup realizado com sucesso!'))
            ]),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _restaurarBackup(File backup) async {
    final nome = backup.path.split('\\').last;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.restore, color: Colors.orange)),
          const SizedBox(width: 12),
          const Text('Restaurar Backup',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Você está prestes a restaurar:'),
              const SizedBox(height: 12),
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3))),
                  child: Row(children: [
                    Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.backup, color: Colors.orange)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(nome,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold))),
                    Text(_formatarData(backup),
                        style: const TextStyle(fontSize: 11))
                  ])),
              const SizedBox(height: 20),
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: Colors.red.withValues(alpha: 0.2))),
                  child: const Row(children: [
                    Icon(Icons.warning_amber, color: Colors.red),
                    SizedBox(width: 12),
                    Expanded(
                        child: Text('Todos os dados atuais serão SUBSTITUÍDOS!',
                            style: TextStyle(color: Colors.red)))
                  ])),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('RESTAURAR')),
        ],
      ),
    );

    if (confirmar != true) return;
    setState(() => carregando = true);
    try {
      final sucesso =
          await _backupService.restaurarBackup(backup.path, limparAntes: true);
      if (sucesso && mounted) {
        await _carregarBackups();
        widget.onBackupRealizado?.call();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Backup restaurado com sucesso!'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erro: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  Future<void> _excluirBackup(File backup) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.delete, color: Colors.red)),
          const SizedBox(width: 12),
          const Text('Excluir Backup',
              style: TextStyle(fontWeight: FontWeight.bold))
        ]),
        content:
            Text('Deseja excluir o backup: ${backup.path.split('\\').last}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('EXCLUIR')),
        ],
      ),
    );
    if (confirmar == true) {
      await backup.delete();
      await _carregarBackups();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('🗑️ Backup excluído'),
          backgroundColor: Colors.orange));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width - 40,
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 550),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader('Backup e Restauração', context),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Expanded(
            child: carregando
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                                onPressed: _fazerBackup,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7B2CBF),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10))),
                                child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.backup),
                                      SizedBox(width: 8),
                                      Text('FAZER BACKUP AGORA')
                                    ]))),
                        const SizedBox(height: 16),
                        if (backups.isEmpty)
                          const Center(
                              child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Column(children: [
                                    Icon(Icons.cloud_off,
                                        size: 48, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text('Nenhum backup encontrado')
                                  ]))),
                        ...backups.map((backup) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(12)),
                                child: Row(children: [
                                  Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                          color: const Color(0xFF7B2CBF)
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: const Icon(Icons.backup,
                                          color: Color(0xFF7B2CBF))),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(backup.path.split('\\').last,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        Text(_formatarData(backup),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey))
                                      ])),
                                  Row(children: [
                                    IconButton(
                                        onPressed: () =>
                                            _restaurarBackup(backup),
                                        icon: const Icon(Icons.restore,
                                            color: Colors.green)),
                                    IconButton(
                                        onPressed: () => _excluirBackup(backup),
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red)),
                                  ]),
                                ]),
                              ),
                            )),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A))),
          GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.close, size: 20, color: Colors.grey[500])),
        ],
      ),
    );
  }
}
