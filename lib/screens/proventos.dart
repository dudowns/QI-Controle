// lib/screens/proventos.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/provento_model.dart';
import '../services/notification_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../widgets/modern_card.dart';
import '../widgets/gradient_button.dart';
import '../utils/formatters.dart';
import '../widgets/adicionar_provento_modal.dart'; // 🔥 NOVO IMPORT!
import 'editar_provento.dart';

class ProventosScreen extends StatefulWidget {
  const ProventosScreen({super.key});

  @override
  State<ProventosScreen> createState() => _ProventosScreenState();
}

class _ProventosScreenState extends State<ProventosScreen> {
  final DBHelper _dbHelper = DBHelper();
  List<Map<String, dynamic>> _proventos = [];
  bool _carregando = true;
  Map<String, dynamic>? _resumo;
  List<String> _tickersDisponiveis = []; // 🔥 Para o modal

  @override
  void initState() {
    super.initState();
    _carregarProventos();
    _carregarTickers();
  }

  Future<void> _carregarTickers() async {
    try {
      final investimentos = await _dbHelper.getAllInvestimentos();
      setState(() {
        _tickersDisponiveis =
            investimentos.map((inv) => inv['ticker'] as String).toList();
      });
    } catch (e) {
      debugPrint('Erro ao carregar tickers: $e');
    }
  }

  Future<void> _carregarProventos() async {
    if (!mounted) return;
    setState(() => _carregando = true);

    try {
      final proventos = await _dbHelper.getAllProventos();
      final resumo = await _calcularResumo(proventos);

      if (mounted) {
        setState(() {
          _proventos = proventos;
          _resumo = resumo;
          _carregando = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar proventos: $e');
      if (mounted) {
        setState(() => _carregando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar proventos: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _calcularResumo(
      List<Map<String, dynamic>> proventos) async {
    double totalRecebido = 0;
    double totalProjetado = 0;
    int proximos = 0;
    final hoje = DateTime.now();

    for (var p in proventos) {
      final dataPagamento = DateTime.parse(p['data_pagamento']);
      final valor = (p['total_recebido'] ?? 0).toDouble();

      if (dataPagamento.isBefore(hoje)) {
        totalRecebido += valor;
      } else {
        totalProjetado += valor;
        if (dataPagamento.difference(hoje).inDays <= 30) {
          proximos++;
        }
      }
    }

    return {
      'totalRecebido': totalRecebido,
      'totalProjetado': totalProjetado,
      'proximos': proximos,
      'total': proventos.length,
    };
  }

  Future<void> _excluirProvento(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context), // ✅ DINÂMICO!
        title: Text(
          'Excluir Provento',
          style:
              TextStyle(color: AppColors.textPrimary(context)), // ✅ DINÂMICO!
        ),
        content: Text(
          'Deseja realmente excluir este provento?',
          style:
              TextStyle(color: AppColors.textSecondary(context)), // ✅ DINÂMICO!
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(
                  color: AppColors.textSecondary(context)), // ✅ DINÂMICO!
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _dbHelper.deleteProvento(id);
        await _carregarProventos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Provento excluído!'),
              backgroundColor: Colors.orange,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context), // ✅ DINÂMICO!
      appBar: AppBar(
        title: const Text('Proventos'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarProventos,
          ),
        ],
      ),
      body: _carregando
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _proventos.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildResumoCard(),
                      const SizedBox(height: 20),
                      ..._proventos.map((p) => _buildProventoCard(p)).toList(),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          if (_tickersDisponiveis.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Primeiro adicione um investimento'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }

          // 🔥 AGORA USA O MODAL!
          AdicionarProventoModal.show(
            context: context,
            tickersDisponiveis: _tickersDisponiveis,
            onSalvo: () {
              _carregarProventos();
              _carregarTickers();
            },
          );
        },
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
              Icons.paid_outlined,
              size: 64,
              color: AppColors.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Nenhum provento cadastrado',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(context), // ✅ DINÂMICO!
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Adicione proventos de ações, FIIs e renda fixa',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(context), // ✅ DINÂMICO!
            ),
          ),
          const SizedBox(height: 24),
          GradientButton(
            text: 'ADICIONAR PROVENTO',
            icon: Icons.add,
            onPressed: () {
              if (_tickersDisponiveis.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Primeiro adicione um investimento'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              AdicionarProventoModal.show(
                context: context,
                tickersDisponiveis: _tickersDisponiveis,
                onSalvo: () {
                  _carregarProventos();
                  _carregarTickers();
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResumoCard() {
    final totalRecebido = _resumo?['totalRecebido'] ?? 0.0;
    final totalProjetado = _resumo?['totalProjetado'] ?? 0.0;
    final proximos = _resumo?['proximos'] ?? 0;

    return ModernCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Recebido',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context), // ✅ DINÂMICO!
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Formatador.moeda(totalRecebido),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Projetado',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context), // ✅ DINÂMICO!
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Formatador.moeda(totalProjetado),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.event_available,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  '$proximos proventos nos próximos 30 dias',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProventoCard(Map<String, dynamic> provento) {
    final ticker = provento['ticker'] ?? '---';
    final tipo = provento['tipo_provento'] ?? 'Dividendo';
    final valorPorCota = (provento['valor_por_cota'] ?? 0).toDouble();
    final quantidade = (provento['quantidade'] ?? 1).toDouble();
    final total = (provento['total_recebido'] ?? 0).toDouble();
    final dataPagamento = DateTime.parse(provento['data_pagamento']);
    final dataCom = provento['data_com'] != null
        ? DateTime.parse(provento['data_com'])
        : null;

    final hoje = DateTime.now();
    final isFuturo = dataPagamento.isAfter(hoje);
    final diasParaPagamento = dataPagamento.difference(hoje).inDays;

    Color statusColor = isFuturo
        ? diasParaPagamento <= 7
            ? Colors.orange
            : AppColors.primary
        : AppColors.success;

    String statusText = isFuturo
        ? diasParaPagamento == 0
            ? 'Hoje'
            : diasParaPagamento == 1
                ? 'Amanhã'
                : 'Em $diasParaPagamento dias'
        : 'Pago';

    return ModernCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.paid,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticker,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context), // ✅ DINÂMICO!
                      ),
                    ),
                    Text(
                      tipo,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context), // ✅ DINÂMICO!
                      ),
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
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Valor/Cota',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary(context), // ✅ DINÂMICO!
                    ),
                  ),
                  Text(
                    Formatador.moeda(valorPorCota),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(context), // ✅ DINÂMICO!
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Quantidade',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary(context), // ✅ DINÂMICO!
                    ),
                  ),
                  Text(
                    quantidade.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(context), // ✅ DINÂMICO!
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary(context), // ✅ DINÂMICO!
                    ),
                  ),
                  Text(
                    Formatador.moeda(total),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isFuturo ? AppColors.primary : AppColors.success,
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
                    color: AppColors.textSecondary(context), // ✅ DINÂMICO!
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Pag: ${Formatador.data(dataPagamento)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary(context), // ✅ DINÂMICO!
                    ),
                  ),
                ],
              ),
              if (dataCom != null)
                Row(
                  children: [
                    Icon(
                      Icons.event,
                      size: 12,
                      color: AppColors.textSecondary(context), // ✅ DINÂMICO!
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Com: ${Formatador.data(dataCom)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(context), // ✅ DINÂMICO!
                      ),
                    ),
                  ],
                ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: Colors.red[300],
                    onPressed: () => _excluirProvento(provento['id']),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
