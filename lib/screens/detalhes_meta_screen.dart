// lib/screens/detalhes_meta_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../repositories/meta_repository.dart';
import 'adicionar_deposito.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../utils/formatters.dart'; // ✅ ÚNICO IMPORT!

class DetalhesMetaScreen extends StatefulWidget {
  final Map<String, dynamic> meta;

  const DetalhesMetaScreen({super.key, required this.meta});

  @override
  State<DetalhesMetaScreen> createState() => _DetalhesMetaScreenState();
}

class _DetalhesMetaScreenState extends State<DetalhesMetaScreen> {
  final MetaRepository _metaRepo = MetaRepository();

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
      depositos = await _metaRepo.getDepositosByMetaId(metaAtual['id']);

      final metaAtualizada = await _metaRepo.getMetaById(metaAtual['id']);
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
            backgroundColor: Colors.red,
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
    return Formatador.moeda(valor); // ✅ USANDO Formatador
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
        return const Color(0xFF6A1B9A);
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
        title: const Text('Excluir Depósito'),
        content: Text(
            'Deseja realmente excluir este depósito de ${_formatarValor(valor)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      if (!mounted) return;
      setState(() => carregando = true);

      try {
        final sucesso = await _metaRepo.removerDepositoEAtualizarMeta(id);

        if (sucesso && mounted) {
          await _carregarDepositos();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Depósito excluído!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('Falha ao excluir depósito');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir: $e'),
              backgroundColor: Colors.red,
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Funcionalidade em desenvolvimento'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _excluirMeta() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Meta'),
        content:
            Text('Deseja realmente excluir a meta "${metaAtual['titulo']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      try {
        await _metaRepo.deleteMeta(metaAtual['id']);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Meta excluída!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(metaAtual['titulo'] ?? 'Detalhes da Meta'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editarMeta,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _excluirMeta,
          ),
        ],
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Card principal
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    metaAtual['titulo'] ?? 'Sem título',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
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
                                        color: Colors.grey[600],
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
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.check_circle,
                                        color: Colors.green, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Concluída',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 10),

                        // Progresso
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Progresso',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${percentual.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: percentual >= 100 ? Colors.green : cor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progresso.clamp(0.0, 1.0),
                            backgroundColor: Colors.grey[200],
                            color: percentual >= 100 ? Colors.green : cor,
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
                                const Text(
                                  'Valor Atual',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
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
                                const Text(
                                  'Meta',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatarValor(valorObjetivo),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Datas - ✅ CORRIGIDO!
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today,
                                      size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Data limite:',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              Text(
                                Formatador.data(// ✅ AGORA SIM!
                                    DateTime.parse(metaAtual['data_fim'])),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
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
                            color: const Color(0xFF6A1B9A).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF6A1B9A).withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.trending_up,
                                      color: Color(0xFF6A1B9A), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Falta alcançar:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _formatarValor((valorObjetivo - valorAtual)
                                    .clamp(0, valorObjetivo)),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6A1B9A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Botão de adicionar depósito
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: concluida
                          ? null
                          : () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AdicionarDepositoScreen(
                                    metaId: metaAtual['id'],
                                    valorAtual: valorAtual,
                                    valorObjetivo: valorObjetivo,
                                  ),
                                ),
                              );

                              if (result == true && mounted) {
                                await _carregarDepositos();
                              }
                            },
                      icon: const Icon(Icons.add),
                      label: const Text('ADICIONAR DEPÓSITO'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6A1B9A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Histórico de depósitos
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Histórico de Depósitos',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (depositos.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF6A1B9A).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${depositos.length} ${depositos.length == 1 ? 'depósito' : 'depósitos'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6A1B9A),
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
                                    size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 8),
                                Text(
                                  'Nenhum depósito ainda',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Clique no botão acima para começar',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
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
                                  color: Colors.red,
                                  child: const Icon(Icons.delete,
                                      color: Colors.white),
                                ),
                                confirmDismiss: (direction) async {
                                  return await showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Confirmar'),
                                      content: const Text(
                                          'Deseja excluir este depósito?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
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
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.paid,
                                              size: 20,
                                              color: Color(0xFF6A1B9A)),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _formatarValor(
                                                    (deposito['valor'] ?? 0)
                                                        .toDouble()),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                Formatador.data(// ✅ CORRIGIDO!
                                                    DateTime.parse(deposito[
                                                        'data_deposito'])),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[500],
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
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6A1B9A)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            deposito['observacao'],
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF6A1B9A),
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
    );
  }
}
