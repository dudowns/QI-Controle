// lib/screens/analise_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../repositories/investimento_repository.dart';
import '../repositories/provento_repository.dart';
import '../models/investimento_model.dart';
import '../models/provento_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';
import '../widgets/primary_card.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/empty_state.dart';
import '../utils/formatters.dart';

class AnaliseScreen extends StatefulWidget {
  const AnaliseScreen({super.key});

  @override
  State<AnaliseScreen> createState() => _AnaliseScreenState();
}

class _AnaliseScreenState extends State<AnaliseScreen> {
  // Repositórios
  final InvestimentoRepository _investimentoRepo = InvestimentoRepository();
  final ProventoRepository _proventoRepo = ProventoRepository();

  // Dados
  List<Investimento> investimentos = [];
  List<Provento> proventos = [];
  List<Map<String, dynamic>> rendaFixa = [];

  bool carregando = true;

  // Filtros
  String periodoSelecionado = '1A';
  final List<String> periodos = ['6M', '1A', '2A', 'TODOS'];

  String ativoSelecionado = 'TODOS';
  List<String> ativosList = ['TODOS'];

  // Controle de categorias visíveis
  Map<String, bool> categoriasVisiveis = {
    'ACAO': true,
    'FII': true,
    'RENDA_FIXA': true,
    'CRIPTO': true,
    'BDR': true,
    'ETF': true,
    'OUTROS': true,
  };

  // Dados para gráficos
  Map<String, double> proventosPorMes = {};
  Map<String, double> proventosPorAno = {};
  Map<String, double> proventosPorTicker = {};

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => carregando = true);

    try {
      // Carregar dados dos repositórios
      investimentos = await _investimentoRepo.getAllInvestimentosModel();
      proventos = await _proventoRepo.getAll();
      rendaFixa = await DBHelper().getAllRendaFixa();

      _processarDadosReais();

      // Atualiza lista de ativos para filtro
      ativosList = ['TODOS'];
      for (var inv in investimentos) {
        if (!ativosList.contains(inv.ticker)) {
          ativosList.add(inv.ticker);
        }
      }

      setState(() => carregando = false);
    } catch (e) {
      debugPrint('❌ Erro ao carregar análise: $e');
      setState(() => carregando = false);
    }
  }

  void _processarDadosReais() {
    proventosPorMes.clear();
    proventosPorAno.clear();
    proventosPorTicker.clear();

    // Processar proventos de ações/FIIs
    for (var p in proventos) {
      try {
        final data = p.dataPagamento;
        final valor = p.totalRecebido;
        final ticker = p.ticker;

        final chaveMes = DateFormat('MM/yyyy').format(data);
        proventosPorMes[chaveMes] = (proventosPorMes[chaveMes] ?? 0) + valor;

        final chaveAno = DateFormat('yyyy').format(data);
        proventosPorAno[chaveAno] = (proventosPorAno[chaveAno] ?? 0) + valor;

        proventosPorTicker[ticker] = (proventosPorTicker[ticker] ?? 0) + valor;
      } catch (e) {
        continue;
      }
    }

    // Adicionar renda fixa como "proventos"
    for (var rf in rendaFixa) {
      try {
        final dataVencimento = DateTime.parse(rf['data_vencimento']);
        final rendimento = (rf['rendimento_liquido'] ?? 0).toDouble();

        if (rendimento > 0) {
          final chaveMes = DateFormat('MM/yyyy').format(dataVencimento);
          proventosPorMes[chaveMes] =
              (proventosPorMes[chaveMes] ?? 0) + rendimento;

          final chaveAno = DateFormat('yyyy').format(dataVencimento);
          proventosPorAno[chaveAno] =
              (proventosPorAno[chaveAno] ?? 0) + rendimento;

          proventosPorTicker[rf['nome']] =
              (proventosPorTicker[rf['nome']] ?? 0) + rendimento;
        }
      } catch (e) {
        continue;
      }
    }
  }

  // ========== CÁLCULOS ==========
  double get patrimonioTotal {
    double total = 0;

    for (var inv in investimentos) {
      total += inv.valorAtual;
    }

    for (var rf in rendaFixa) {
      total += rf['valor_final'] ?? rf['valor'] ?? 0;
    }

    return total;
  }

  double get valorInvestido {
    double total = 0;

    for (var inv in investimentos) {
      total += inv.valorInvestido;
    }

    for (var rf in rendaFixa) {
      total += rf['valor'] ?? 0;
    }

    return total;
  }

  double get ganhoCapital => patrimonioTotal - valorInvestido;
  double get percentualGanho =>
      valorInvestido > 0 ? (ganhoCapital / valorInvestido) * 100 : 0;

  // ========== GRÁFICO PIZZA ==========
  List<Map<String, dynamic>> get dadosPizza {
    final Map<String, double> valores = {};

    // Investimentos variáveis
    for (var inv in investimentos) {
      final tipo = inv.tipo.nome;
      if (!(categoriasVisiveis[tipo] ?? true)) continue;
      valores[tipo] = (valores[tipo] ?? 0) + inv.valorAtual;
    }

    // Renda Fixa
    if (rendaFixa.isNotEmpty && (categoriasVisiveis['RENDA_FIXA'] ?? true)) {
      double totalRF = 0;
      for (var rf in rendaFixa) {
        totalRF += rf['valor_final'] ?? rf['valor'] ?? 0;
      }
      if (totalRF > 0) {
        valores['RENDA_FIXA'] = totalRF;
      }
    }

    return valores.entries.map((e) {
      return {
        'tipo': e.key,
        'valor': e.value,
        'percentual':
            patrimonioTotal > 0 ? (e.value / patrimonioTotal) * 100 : 0,
      };
    }).toList();
  }

  // ========== DADOS POR CATEGORIA ==========
  Map<String, List<dynamic>> get investimentosPorTipo {
    final Map<String, List<dynamic>> agrupado = {};

    // Investimentos variáveis
    for (var inv in investimentos) {
      final tipo = inv.tipo.nome;
      if (!(categoriasVisiveis[tipo] ?? true)) continue;
      if (!agrupado.containsKey(tipo)) {
        agrupado[tipo] = [];
      }
      agrupado[tipo]!.add(inv);
    }

    // Renda Fixa (como uma categoria separada)
    if (rendaFixa.isNotEmpty && (categoriasVisiveis['RENDA_FIXA'] ?? true)) {
      agrupado['RENDA_FIXA'] = rendaFixa
          .map((rf) => {
                'ticker': rf['nome'],
                'tipo': 'RENDA_FIXA',
                'quantidade': 1,
                'preco_medio': rf['valor'],
                'preco_atual': rf['valor_final'] ?? rf['valor'],
                'data_compra': rf['data_aplicacao'],
                'taxa': rf['taxa'],
                'vencimento': rf['data_vencimento'],
              })
          .toList();
    }

    return agrupado;
  }

  // ========== PROVENTOS ==========
  double get proventosUltimos12Meses {
    final hoje = DateTime.now();
    final umAnoAtras = DateTime(hoje.year - 1, hoje.month, hoje.day);
    double total = 0;

    for (var p in proventos) {
      try {
        if (p.dataPagamento.isAfter(umAnoAtras)) {
          total += p.totalRecebido;
        }
      } catch (e) {}
    }

    return total;
  }

  double get proventosMesAtual {
    final hoje = DateTime.now();
    double total = 0;

    for (var p in proventos) {
      try {
        if (p.dataPagamento.month == hoje.month &&
            p.dataPagamento.year == hoje.year) {
          total += p.totalRecebido;
        }
      } catch (e) {}
    }

    return total;
  }

  // ========== BUILD ==========
  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final formatador = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Análise'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarDados,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== CARDS RESUMO ==========
            Row(
              children: [
                Expanded(
                  child: _buildResumoCard(
                    'Patrimônio',
                    formatador.format(patrimonioTotal),
                    Icons.account_balance_wallet,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildResumoCard(
                    'Investido',
                    formatador.format(valorInvestido),
                    Icons.trending_down,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildResumoCard(
                    'Ganho',
                    '${formatador.format(ganhoCapital)} (${percentualGanho.toStringAsFixed(1)}%)',
                    Icons.trending_up,
                    ganhoCapital >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ========== GRÁFICOS ==========
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // GRÁFICO PIZZA
                Expanded(
                  flex: 4,
                  child: _buildGraficoPizza(),
                ),
                const SizedBox(width: 12),
                // GRÁFICO PROVENTOS POR MÊS
                Expanded(
                  flex: 6,
                  child: _buildGraficoProventos(),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ========== ALOCAÇÃO POR ATIVO ==========
            _buildAlocacaoExpandivel(),

            const SizedBox(height: 20),

            // ========== PROVENTOS ==========
            _buildProventosCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildResumoCard(
      String titulo, String valor, IconData icone, Color cor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, color: cor, size: 16),
              const SizedBox(width: 4),
              Text(
                titulo,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            valor,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildGraficoPizza() {
    if (dadosPizza.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'Sem dados para exibir',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribuição',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...dadosPizza.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getCorPorTipo(item['tipo']),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getNomeTipo(item['tipo']),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    '${item['percentual'].toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGraficoProventos() {
    if (proventosPorMes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'Sem histórico de proventos',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Pegar últimos 6 meses
    final ultimosMeses = proventosPorMes.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final ultimos6 = ultimosMeses.length > 6
        ? ultimosMeses.sublist(ultimosMeses.length - 6)
        : ultimosMeses;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Proventos por Mês',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ultimos6.map((entry) {
                final valor = entry.value;
                final double altura =
                    valor > 0 ? (valor / 100).clamp(20, 80) : 20;

                return Column(
                  children: [
                    Container(
                      width: 20,
                      height: altura,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6A1B9A).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.key.split('/')[0],
                      style: const TextStyle(fontSize: 9),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlocacaoExpandivel() {
    if (investimentosPorTipo.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Alocação por Ativo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) {
                  if (value == 'gerenciar') {
                    _showGerenciarCategorias();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'gerenciar',
                    child: Text('Gerenciar categorias'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...investimentosPorTipo.entries.map((entry) {
            return _buildCategoriaTile(entry.key, entry.value);
          }),
        ],
      ),
    );
  }

  Widget _buildCategoriaTile(String categoria, List<dynamic> ativos) {
    final formatador = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    double totalCategoria = 0;

    for (var item in ativos) {
      if (item is Investimento) {
        totalCategoria += item.valorAtual;
      } else if (item is Map<String, dynamic>) {
        totalCategoria += (item['preco_atual'] ?? item['preco_medio']) * 1;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: EdgeInsets.zero,
          title: Row(
            children: [
              Expanded(
                child: Text(
                  _getNomeTipo(categoria),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                formatador.format(totalCategoria),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    categoriasVisiveis[categoria] = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 12),
                ),
              ),
            ],
          ),
          children: [
            const Divider(height: 1),
            ...ativos.map((item) => _buildAtivoTile(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildAtivoTile(dynamic item) {
    final formatador = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    if (item is Investimento) {
      final variacao = item.variacaoPercentual;

      return Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.ticker,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  formatador.format(item.valorAtual),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Qnt: ${item.quantidade.toStringAsFixed(0)} | PM: R\$ ${item.precoMedio.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                Text(
                  'Atual: R\$ ${(item.precoAtual ?? item.precoMedio).toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: variacao >= 0 ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${variacao >= 0 ? '+' : ''}${variacao.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color:
                          variacao >= 0 ? Colors.green[700] : Colors.red[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else if (item is Map<String, dynamic>) {
      final precoMedio = (item['preco_medio'] ?? 0).toDouble();
      final precoAtual = (item['preco_atual'] ?? precoMedio).toDouble();
      final variacao =
          precoMedio > 0 ? ((precoAtual - precoMedio) / precoMedio) * 100 : 0;

      return Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item['ticker'] ?? item['nome'] ?? 'Ativo',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  formatador.format(precoAtual),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Qnt: ${(item['quantidade'] ?? 1).toStringAsFixed(0)} | PM: R\$ ${precoMedio.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                Text(
                  'Atual: R\$ ${precoAtual.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: variacao >= 0 ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${variacao >= 0 ? '+' : ''}${variacao.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color:
                          variacao >= 0 ? Colors.green[700] : Colors.red[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildProventosCard() {
    final formatador = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [const Color(0xFF6A1B9A).withOpacity(0.1), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💰 Proventos',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildProventoItem(
                'Últimos 12 meses',
                formatador.format(proventosUltimos12Meses),
                Icons.calendar_today,
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.grey[300],
              ),
              _buildProventoItem(
                'Mês atual',
                formatador.format(proventosMesAtual),
                Icons.today,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProventoItem(String label, String valor, IconData icone) {
    return Column(
      children: [
        Icon(icone, color: const Color(0xFF6A1B9A), size: 20),
        const SizedBox(height: 4),
        Text(
          valor,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  void _showGerenciarCategorias() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Gerenciar Categorias',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ...categoriasVisiveis.keys.map((categoria) {
                return CheckboxListTile(
                  title: Text(_getNomeTipo(categoria)),
                  value: categoriasVisiveis[categoria],
                  activeColor: const Color(0xFF6A1B9A),
                  onChanged: (value) {
                    setState(() {
                      categoriasVisiveis[categoria] = value!;
                    });
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  String _getNomeTipo(String tipo) {
    switch (tipo) {
      case 'ACAO':
        return 'Ações';
      case 'FII':
        return 'FIIs';
      case 'RENDA_FIXA':
        return 'Renda Fixa';
      case 'CRIPTO':
        return 'Cripto';
      case 'BDR':
        return 'BDRs';
      case 'ETF':
        return 'ETFs';
      default:
        return tipo;
    }
  }

  Color _getCorPorTipo(String tipo) {
    switch (tipo) {
      case 'ACAO':
        return Colors.blue;
      case 'FII':
        return Colors.green;
      case 'RENDA_FIXA':
        return Colors.orange;
      case 'CRIPTO':
        return Colors.purple;
      case 'BDR':
        return Colors.teal;
      case 'ETF':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }
}
