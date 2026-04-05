// lib/widgets/detalhes_meta_modal.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/gradient_button.dart';
import 'adicionar_deposito_modal.dart';
import 'editar_meta_modal.dart';

class DetalhesMetaModal extends StatefulWidget {
  final Map<String, dynamic> meta;
  final Future<void> Function()? onMetaAlterada;

  const DetalhesMetaModal({
    super.key,
    required this.meta,
    this.onMetaAlterada,
  });

  @override
  State<DetalhesMetaModal> createState() => _DetalhesMetaModalState();

  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> meta,
    Future<void> Function()? onMetaAlterada,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DetalhesMetaModal(
          meta: meta,
          onMetaAlterada: onMetaAlterada,
        ),
      ),
    );
  }
}

class _DetalhesMetaModalState extends State<DetalhesMetaModal> {
  final DBHelper _dbHelper = DBHelper();

  List<Map<String, dynamic>> depositos = [];
  late Map<String, dynamic> metaAtual;
  bool carregando = false;

  @override
  void initState() {
    super.initState();
    metaAtual = Map.from(widget.meta);
    _carregarDepositos();
  }

  Future<void> _carregarDepositos() async {
    if (!mounted) return;
    setState(() => carregando = true);

    try {
      depositos = await _dbHelper.getDepositosByMetaId(metaAtual['id']);

      final metaAtualizada = await _dbHelper.getMetaById(metaAtual['id']);
      if (metaAtualizada != null && mounted) {
        setState(() {
          metaAtual = metaAtualizada;
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar depósitos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar depósitos: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => carregando = false);
      }
    }
  }

  String _formatarValor(double valor) {
    return Formatador.moeda(valor);
  }

  Color _getCorPorTipo(String? cor) {
    switch (cor) {
      case 'viagem':
        return Colors.blue;
      case 'carro':
        return Colors.red;
      case 'casa':
        return Colors.green;
      case 'estudo':
        return Colors.orange;
      case 'investimento':
        return Colors.purple;
      default:
        return AppColors.primary;
    }
  }

  IconData _getIconePorTipo(String? icone) {
    switch (icone) {
      case 'viagem':
        return Icons.flight;
      case 'carro':
        return Icons.directions_car;
      case 'casa':
        return Icons.home;
      case 'estudo':
        return Icons.school;
      case 'investimento':
        return Icons.trending_up;
      default:
        return Icons.flag;
    }
  }

  Future<void> _excluirDeposito(int id, double valor) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete, color: AppColors.error),
            ),
            const SizedBox(width: 12),
            Text(
              'Excluir Depósito',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
        content: Text(
          'Deseja realmente excluir este depósito de ${_formatarValor(valor)}?',
          style: TextStyle(color: AppColors.textSecondary(context)),
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
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      if (!mounted) return;
      setState(() => carregando = true);

      try {
        await _dbHelper.deleteDeposito(id);

        final depositosAtuais =
            await _dbHelper.getDepositosByMetaId(metaAtual['id']);
        double novoValor = 0;
        for (var d in depositosAtuais) {
          novoValor += (d['valor'] ?? 0).toDouble();
        }

        await _dbHelper.atualizarProgressoMeta(metaAtual['id'], novoValor);

        if (mounted) {
          await _carregarDepositos();
          if (widget.onMetaAlterada != null) {
            await widget.onMetaAlterada!();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Depósito excluído!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => carregando = false);
        }
      }
    }
  }

  Future<void> _editarMeta() async {
    await EditarMetaModal.show(
      context: context,
      meta: metaAtual,
      onSalvo: () async {
        await _carregarDepositos();
        if (widget.onMetaAlterada != null) {
          await widget.onMetaAlterada!();
        }
      },
    );
  }

  Future<void> _excluirMeta() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete, color: AppColors.error),
            ),
            const SizedBox(width: 12),
            Text(
              'Excluir Meta',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
        content: Text(
          'Deseja realmente excluir a meta "${metaAtual['titulo']}"?\n\nTodos os depósitos também serão excluídos.',
          style: TextStyle(color: AppColors.textSecondary(context)),
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
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      try {
        await _dbHelper.deleteMeta(metaAtual['id']);
        if (mounted) {
          if (widget.onMetaAlterada != null) {
            await widget.onMetaAlterada!();
          }
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Meta excluída!'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _adicionarDeposito() async {
    await AdicionarDepositoModal.show(
      context: context,
      metaId: metaAtual['id'],
      valorAtual: (metaAtual['valor_atual'] ?? 0).toDouble(),
      valorObjetivo: (metaAtual['valor_objetivo'] ?? 0).toDouble(),
      onDepositoAdicionado: () async {
        await _carregarDepositos();
        if (widget.onMetaAlterada != null) {
          await widget.onMetaAlterada!();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final valorObjetivo = (metaAtual['valor_objetivo'] ?? 0).toDouble();
    final valorAtual = (metaAtual['valor_atual'] ?? 0).toDouble();
    final progresso = valorObjetivo > 0 ? valorAtual / valorObjetivo : 0.0;
    final percentual = (progresso * 100).clamp(0, 100);
    final cor = _getCorPorTipo(metaAtual['cor']);
    final icone = _getIconePorTipo(metaAtual['icone']);
    final concluida = metaAtual['concluida'] == 1;

    return carregando
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // CABEÇALHO
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
                    Expanded(
                      child: Text(
                        metaAtual['titulo'] ?? 'Detalhes da Meta',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            color: Colors.white,
                            onPressed: _editarMeta,
                            tooltip: 'Editar meta',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            color: Colors.white,
                            onPressed: _excluirMeta,
                            tooltip: 'Excluir meta',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // CONTEÚDO
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Card principal
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border(context)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: cor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Icon(icone, color: cor, size: 30),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        metaAtual['titulo'] ?? 'Sem título',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary(context),
                                        ),
                                      ),
                                      if (metaAtual['descricao'] != null &&
                                          metaAtual['descricao']
                                              .toString()
                                              .isNotEmpty)
                                        Text(
                                          metaAtual['descricao'],
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.textSecondary(
                                                context),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (concluida)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.check_circle,
                                            color: AppColors.success, size: 16),
                                        SizedBox(width: 4),
                                        Text(
                                          'Concluída',
                                          style: TextStyle(
                                            color: AppColors.success,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Divider(color: AppColors.divider(context)),
                            const SizedBox(height: 10),

                            // Progresso
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Progresso',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),
                                Text(
                                  '${percentual.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: percentual >= 100
                                        ? AppColors.success
                                        : cor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progresso.clamp(0.0, 1.0),
                                backgroundColor: AppColors.muted(context),
                                color:
                                    percentual >= 100 ? AppColors.success : cor,
                                minHeight: 12,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Valores
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Valor Atual',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary(context),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatarValor(valorAtual),
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: cor,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Meta',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary(context),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatarValor(valorObjetivo),
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Datas
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.border(context)),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today,
                                          size: 16,
                                          color:
                                              AppColors.textSecondary(context)),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Data limite:',
                                        style: TextStyle(
                                            color: AppColors.textSecondary(
                                                context)),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    Formatador.data(
                                        DateTime.parse(metaAtual['data_fim'])),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Falta alcançar
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cor.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: cor.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.trending_up,
                                          color: cor, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Falta alcançar:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _formatarValor((valorObjetivo - valorAtual)
                                        .clamp(0, valorObjetivo)),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: cor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Botão Adicionar Depósito
                      if (concluida)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.muted(context),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'META CONCLUÍDA',
                              style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: GradientButton(
                            text: 'ADICIONAR DEPÓSITO',
                            onPressed: _adicionarDeposito,
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Histórico de depósitos
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Histórico de Depósitos',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),
                                if (depositos.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${depositos.length} ${depositos.length == 1 ? 'depósito' : 'depósitos'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: cor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (depositos.isEmpty)
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.history,
                                        size: 48,
                                        color: AppColors.muted(context)),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Nenhum depósito ainda',
                                      style: TextStyle(
                                          color:
                                              AppColors.textSecondary(context)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Clique no botão acima para começar',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: depositos.length,
                                itemBuilder: (context, index) {
                                  final deposito = depositos[index];
                                  return Dismissible(
                                    key: Key('deposito_${deposito['id']}'),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      color: AppColors.error,
                                      child: const Icon(Icons.delete,
                                          color: Colors.white),
                                    ),
                                    confirmDismiss: (direction) async {
                                      return await showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor:
                                              AppColors.surface(context),
                                          title: Text(
                                            'Confirmar',
                                            style: TextStyle(
                                              color: AppColors.textPrimary(
                                                  context),
                                            ),
                                          ),
                                          content: const Text(
                                              'Deseja excluir este depósito?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: Text(
                                                'Cancelar',
                                                style: TextStyle(
                                                  color:
                                                      AppColors.textSecondary(
                                                          context),
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    AppColors.error,
                                              ),
                                              child: const Text('Excluir'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    onDismissed: (direction) {
                                      _excluirDeposito(
                                        deposito['id'],
                                        (deposito['valor'] ?? 0).toDouble(),
                                      );
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface(context),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: AppColors.border(context)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.paid,
                                                  size: 20, color: cor),
                                              const SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _formatarValor(
                                                        (deposito['valor'] ?? 0)
                                                            .toDouble()),
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          AppColors.textPrimary(
                                                              context),
                                                    ),
                                                  ),
                                                  Text(
                                                    Formatador.data(
                                                        DateTime.parse(deposito[
                                                            'data_deposito'])),
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
                                          if (deposito['observacao'] != null &&
                                              deposito['observacao']
                                                  .toString()
                                                  .isNotEmpty)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: cor.withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                deposito['observacao'],
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: cor,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
  }
}
