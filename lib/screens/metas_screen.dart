// lib/screens/metas_screen.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/nova_meta_modal.dart';
import '../widgets/detalhes_meta_modal.dart';

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
      final metas = await _dbHelper.getAllMetas();
      if (mounted) {
        setState(() {
          _metas = metas;
          _carregando = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar metas: $e');
      if (mounted) {
        setState(() => _carregando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar metas: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            )
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
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          NovaMetaModal.show(
            context: context,
            onSalvo: () => _carregarMetas(),
          );
        },
        tooltip: 'Nova meta',
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
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.flag_outlined,
              size: 64,
              color: AppColors.primary.withOpacity(0.5),
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
            onPressed: () {
              NovaMetaModal.show(
                context: context,
                onSalvo: () => _carregarMetas(),
              );
            },
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
    final titulo = meta['titulo'] ?? 'Sem título';
    final descricao = meta['descricao'] ?? '';
    final valorObjetivo = (meta['valor_objetivo'] ?? 0).toDouble();
    final valorAtual = (meta['valor_atual'] ?? 0).toDouble();
    final dataFim = DateTime.parse(meta['data_fim']);
    final concluida = meta['concluida'] == 1;
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () async {
          await DetalhesMetaModal.show(
            context: context,
            meta: meta,
            onMetaAlterada: () => _carregarMetas(),
          );
        },
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
                      color: cor.withOpacity(0.1),
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
                          titulo,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        if (descricao.isNotEmpty)
                          Text(
                            descricao,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          concluida
                              ? Icons.check_circle
                              : diasRestantes < 0
                                  ? Icons.warning
                                  : Icons.schedule,
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
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Faltam ${Formatador.moeda(falta)}',
                        style: TextStyle(
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
}
