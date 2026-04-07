import '../services/logger_service.dart';
// lib/screens/metas_screen.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/meta_model.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/app_modals.dart';

class MetasScreen extends StatefulWidget {
  const MetasScreen({super.key});

  @override
  State<MetasScreen> createState() => _MetasScreenState();
}

class _MetasScreenState extends State<MetasScreen> {
  final DBHelper _dbHelper = DBHelper();

  List<Map<String, dynamic>> _metas = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarMetas();
  }

  Future<void> _carregarMetas() async {
    if (!mounted) return;
    setState(() => _carregando = true);

    try {
      _metas = await _dbHelper.getAllMetas();
    } catch (e) {
      LoggerService.info('❌ Erro ao carregar metas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar metas: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _adicionarMeta() async {
    final resultado = await AppModals.mostrarModalMeta(context: context);
    if (resultado != null) {
      await _salvarMeta(resultado);
    }
  }

  Future<void> _editarMeta(Map<String, dynamic> meta) async {
    final resultado = await AppModals.mostrarModalMeta(
      context: context,
      meta: meta,
    );
    if (resultado != null) {
      await _atualizarMeta(resultado);
    }
  }

  Future<void> _salvarMeta(Map<String, dynamic> meta) async {
    try {
      await _dbHelper.insertMeta(meta);
      await _carregarMetas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎯 Meta criada com sucesso!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar meta: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _atualizarMeta(Map<String, dynamic> meta) async {
    try {
      await _dbHelper.updateMeta(meta);
      await _carregarMetas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✏️ Meta atualizada!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _excluirMeta(int id, String titulo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: const Text('Excluir Meta'),
        content: Text('Deseja excluir "$titulo"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _dbHelper.deleteMeta(id);
        await _carregarMetas();
        if (mounted) {
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

  Future<void> _adicionarDeposito(Map<String, dynamic> meta) async {
    final resultado = await AppModals.mostrarModalDeposito(
      context: context,
      meta: meta,
    );
    if (resultado != null) {
      await _salvarDeposito(
          meta['id'], resultado['valor'], resultado['observacao']);
    }
  }

  Future<void> _salvarDeposito(
      int metaId, double valor, String? observacao) async {
    try {
      final deposito = {
        'meta_id': metaId,
        'valor': valor,
        'data_deposito': DateTime.now().toIso8601String(),
        'observacao': observacao,
      };
      await _dbHelper.insertDepositoMeta(deposito);

      final depositos = await _dbHelper.getDepositosByMetaId(metaId);
      double novoValor = 0;
      for (var d in depositos) {
        novoValor += (d['valor'] as num).toDouble();
      }
      await _dbHelper.atualizarProgressoMeta(metaId, novoValor);

      final meta = await _dbHelper.getMetaById(metaId);
      if (meta != null) {
        final valorObjetivo = (meta['valor_objetivo'] as num).toDouble();
        if (novoValor >= valorObjetivo) {
          await _dbHelper.concluirMeta(metaId);
        }
      }

      await _carregarMetas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Depósito adicionado!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar depósito: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Minhas Metas'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarMetas,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _metas.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _metas.length,
                  itemBuilder: (context, index) {
                    final meta = _metas[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildMetaCard(meta),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _adicionarMeta,
        tooltip: 'Nova meta',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha:0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.flag_outlined,
              size: 64,
              color: AppColors.primary.withValues(alpha:0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Nenhuma meta cadastrada',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Comece definindo seus objetivos financeiros',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _adicionarMeta,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 18),
                SizedBox(width: 8),
                Text('CRIAR PRIMEIRA META'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaCard(Map<String, dynamic> meta) {
    final valorObjetivo = (meta['valor_objetivo'] as num).toDouble();
    final valorAtual = (meta['valor_atual'] as num).toDouble();
    final dataFim = DateTime.parse(meta['data_fim']);
    final concluida = (meta['concluida'] as int) == 1;
    final cor = _getCorPorTipo(meta['cor']);
    final icone = _getIconePorTipo(meta['icone']);

    final progresso = valorObjetivo > 0 ? valorAtual / valorObjetivo : 0.0;
    final percentual = (progresso * 100).clamp(0, 100);
    final falta = (valorObjetivo - valorAtual).clamp(0, valorObjetivo);

    final hoje = DateTime.now();
    final diasRestantes = dataFim.difference(hoje).inDays;

    Color statusColor = Colors.green;
    String statusText = 'No prazo';

    if (concluida) {
      statusColor = Colors.green;
      statusText = 'Concluída';
    } else if (diasRestantes < 0) {
      statusColor = Colors.red;
      statusText = 'Atrasada';
    } else if (diasRestantes < 7) {
      statusColor = Colors.orange;
      statusText = 'Próximo do fim';
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _verDetalhesMeta(meta),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cor.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icone, color: cor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meta['titulo'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        if (meta['descricao'] != null &&
                            meta['descricao'].toString().isNotEmpty)
                          Text(
                            meta['descricao'],
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha:0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          concluida
                              ? Icons.check_circle
                              : (diasRestantes < 0
                                  ? Icons.warning
                                  : Icons.schedule),
                          size: 12,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 10,
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progresso',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  Text(
                    '${percentual.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: percentual >= 100 ? Colors.green : cor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progresso.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[200],
                  color: percentual >= 100 ? Colors.green : cor,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Atual',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      Text(
                        Formatador.moeda(valorAtual),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
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
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      Text(
                        Formatador.moeda(valorObjetivo),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: AppColors.textSecondary(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Até ${Formatador.data(dataFim)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  if (!concluida && falta > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Faltam R\$ ${falta.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _verDetalhesMeta(Map<String, dynamic> meta) async {
    final depositos = await _dbHelper.getDepositosByMetaId(meta['id']);
    final valorAtual = (meta['valor_atual'] as num).toDouble();
    final valorObjetivo = (meta['valor_objetivo'] as num).toDouble();
    final dataFim = DateTime.parse(meta['data_fim']);
    final progresso = valorObjetivo > 0 ? valorAtual / valorObjetivo : 0.0;
    final percentual = (progresso * 100).clamp(0, 100);
    final cor = _getCorPorTipo(meta['cor']);
    final icone = _getIconePorTipo(meta['icone']);
    final concluida = (meta['concluida'] as int) == 1;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          meta['titulo'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            color: Colors.white,
                            onPressed: () {
                              Navigator.pop(context);
                              _editarMeta(meta);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            color: Colors.white,
                            onPressed: () async {
                              Navigator.pop(context);
                              _excluirMeta(meta['id'], meta['titulo']);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface(context),
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: AppColors.border(context)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                      color: cor.withValues(alpha:0.1),
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
                                          meta['titulo'],
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                AppColors.textPrimary(context),
                                          ),
                                        ),
                                        if (meta['descricao'] != null &&
                                            meta['descricao']
                                                .toString()
                                                .isNotEmpty)
                                          Text(
                                            meta['descricao'],
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
                                        color:
                                            AppColors.success.withValues(alpha:0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.check_circle,
                                              color: AppColors.success,
                                              size: 16),
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
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                  color: percentual >= 100
                                      ? AppColors.success
                                      : cor,
                                  minHeight: 12,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Valor Atual',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              AppColors.textSecondary(context),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        Formatador.moeda(valorAtual),
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
                                          color:
                                              AppColors.textSecondary(context),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        Formatador.moeda(valorObjetivo),
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
                                        Icon(
                                          Icons.calendar_today,
                                          size: 16,
                                          color:
                                              AppColors.textSecondary(context),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Data limite:',
                                          style: TextStyle(
                                            color: AppColors.textSecondary(
                                                context),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      Formatador.data(dataFim),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cor.withValues(alpha:0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: cor.withValues(alpha:0.2)),
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
                                            color:
                                                AppColors.textPrimary(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      Formatador.moeda(
                                          (valorObjetivo - valorAtual)
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
                        if (!concluida)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _adicionarDeposito(meta),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                              ),
                              child: const Text(
                                'ADICIONAR DEPÓSITO',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface(context),
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: AppColors.border(context)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: cor.withValues(alpha:0.1),
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
                                      Icon(
                                        Icons.history,
                                        size: 48,
                                        color: AppColors.muted(context),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Nenhum depósito ainda',
                                        style: TextStyle(
                                          color:
                                              AppColors.textSecondary(context),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Clique no botão acima para começar',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              AppColors.textSecondary(context),
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
                                    final d = depositos[index];
                                    final valorDeposito =
                                        (d['valor'] as num).toDouble();
                                    final dataDeposito =
                                        DateTime.parse(d['data_deposito']);
                                    return Container(
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
                                                    Formatador.moeda(
                                                        valorDeposito),
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
                                                        dataDeposito),
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
                                          if (d['observacao'] != null &&
                                              d['observacao']
                                                  .toString()
                                                  .isNotEmpty)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: cor.withValues(alpha:0.1),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                d['observacao'],
                                                style: TextStyle(
                                                    fontSize: 11, color: cor),
                                              ),
                                            ),
                                        ],
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
            ),
          );
        },
      ),
    );
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
}

