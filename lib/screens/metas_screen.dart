// lib/screens/metas_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meta_model.dart';
import '../repositories/meta_repository.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';
import '../services/logger_service.dart';
import '../widgets/toast.dart';

class MetasScreen extends StatefulWidget {
  const MetasScreen({super.key});

  @override
  State<MetasScreen> createState() => _MetasScreenState();
}

class _MetasScreenState extends State<MetasScreen> {
  final MetaRepository _metaRepo = MetaRepository();

  List<Map<String, dynamic>> _metas = [];
  Map<String, dynamic>? _resumo;
  bool _isLoading = true;
  String _filtroStatus = 'todas';

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final resultados = await Future.wait([
        _metaRepo.getAllMetas(),
        _metaRepo.getResumoMetas(),
      ]);

      if (mounted) {
        setState(() {
          _metas = resultados[0] as List<Map<String, dynamic>>;
          _resumo = resultados[1] as Map<String, dynamic>?;
        });
      }
    } catch (e) {
      LoggerService.error('Erro ao carregar metas: $e');
      if (mounted) {
        Toast.error(context, 'Erro ao carregar metas');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _metasFiltradas {
    if (_filtroStatus == 'todas') return _metas;
    if (_filtroStatus == 'concluidas') {
      return _metas.where((m) {
        final concluida = m['concluida'] == 1;
        final valorAtual = (m['valor_atual'] as num?)?.toDouble() ?? 0;
        final valorObjetivo = (m['valor_objetivo'] as num?)?.toDouble() ?? 0;
        return concluida || valorAtual >= valorObjetivo;
      }).toList();
    }
    if (_filtroStatus == 'andamento') {
      return _metas.where((m) {
        final concluida = m['concluida'] == 1;
        final valorAtual = (m['valor_atual'] as num?)?.toDouble() ?? 0;
        final valorObjetivo = (m['valor_objetivo'] as num?)?.toDouble() ?? 0;
        return !(concluida || valorAtual >= valorObjetivo);
      }).toList();
    }
    return _metas;
  }

  Future<void> _adicionarMeta() async {
    final resultado = await _mostrarModalMeta();
    if (resultado != null) {
      await _metaRepo.insertMeta(resultado);
      await _carregarDados();
    }
  }

  Future<void> _editarMeta(Map<String, dynamic> meta) async {
    final resultado = await _mostrarModalMeta(meta: meta);
    if (resultado != null) {
      await _metaRepo.updateMeta(resultado);
      await _carregarDados();
    }
  }

  Future<Map<String, dynamic>?> _mostrarModalMeta(
      {Map<String, dynamic>? meta}) async {
    final tituloController =
        TextEditingController(text: meta?['titulo']?.toString() ?? '');
    final descricaoController =
        TextEditingController(text: meta?['descricao']?.toString() ?? '');
    final valorObjetivoController =
        TextEditingController(text: meta?['valor_objetivo']?.toString() ?? '');
    final valorAtualController =
        TextEditingController(text: meta?['valor_atual']?.toString() ?? '');

    String tipoSelecionado = meta?['cor']?.toString() ?? 'geral';
    DateTime? dataInicio = meta?['data_inicio'] != null
        ? DateTime.parse(meta!['data_inicio'].toString())
        : DateTime.now();
    DateTime? dataFim = meta?['data_fim'] != null
        ? DateTime.parse(meta!['data_fim'].toString())
        : null;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getTipoMeta(tipoSelecionado).cor.withValues(alpha: 0.8),
                        _getTipoMeta(tipoSelecionado).cor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _getTipoMeta(tipoSelecionado).emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    meta == null ? 'Nova Meta' : 'Editar Meta',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tipo de Meta',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: TipoMeta.values.map((tipo) {
                        final selecionado = tipo.nome == tipoSelecionado;
                        return GestureDetector(
                          onTap: () =>
                              setStateDialog(() => tipoSelecionado = tipo.nome),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: selecionado
                                  ? tipo.cor.withValues(alpha: 0.15)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color:
                                    selecionado ? tipo.cor : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(tipo.emoji,
                                    style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 6),
                                Text(
                                  tipo.nome.substring(0, 1).toUpperCase() +
                                      tipo.nome.substring(1),
                                  style: TextStyle(
                                    color: selecionado
                                        ? tipo.cor
                                        : Colors.grey[700],
                                    fontWeight: selecionado
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: tituloController,
                    decoration: InputDecoration(
                      labelText: 'Título',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.flag_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descricaoController,
                    decoration: InputDecoration(
                      labelText: 'Descrição (opcional)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.description_outlined),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: valorObjetivoController,
                          decoration: InputDecoration(
                            labelText: 'Valor Objetivo',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            prefixText: 'R\$ ',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: valorAtualController,
                          decoration: InputDecoration(
                            labelText: 'Valor Atual',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            prefixText: 'R\$ ',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dataFim ??
                            DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (picked != null) {
                        setStateDialog(() => dataFim = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              color: _getTipoMeta(tipoSelecionado).cor),
                          const SizedBox(width: 12),
                          Text(
                            'Prazo: ${dataFim != null ? DateFormat('dd/MM/yyyy').format(dataFim!) : 'Selecionar data'}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final titulo = tituloController.text.trim();
                  if (titulo.isEmpty) {
                    Toast.warning(context, 'Digite o título da meta');
                    return;
                  }

                  double valorObjetivo;
                  double valorAtual;
                  try {
                    String valorObjStr = valorObjetivoController.text
                        .replaceAll('R\$', '')
                        .replaceAll(' ', '')
                        .replaceAll(',', '.')
                        .trim();
                    if (valorObjStr.isEmpty) {
                      Toast.warning(context, 'Digite o valor objetivo');
                      return;
                    }
                    valorObjetivo = double.parse(valorObjStr);

                    String valorAtualStr = valorAtualController.text
                        .replaceAll('R\$', '')
                        .replaceAll(' ', '')
                        .replaceAll(',', '.')
                        .trim();
                    valorAtual =
                        valorAtualStr.isEmpty ? 0 : double.parse(valorAtualStr);
                  } catch (e) {
                    Toast.error(context, 'Valor inválido');
                    return;
                  }

                  if (dataFim == null) {
                    Toast.warning(context, 'Selecione a data de conclusão');
                    return;
                  }

                  Navigator.pop(context, {
                    'id': meta?['id'],
                    'titulo': titulo,
                    'descricao': descricaoController.text.trim(),
                    'valor_objetivo': valorObjetivo,
                    'valor_atual': valorAtual,
                    'data_inicio': DateFormat('yyyy-MM-dd')
                        .format(dataInicio ?? DateTime.now()),
                    'data_fim': DateFormat('yyyy-MM-dd').format(dataFim!),
                    'cor': tipoSelecionado,
                    // 'type': tipoSelecionado,
                    // 'icon': _getTipoMeta(tipoSelecionado).emoji,
                    'concluida': meta?['concluida'] ?? 0,
                  });
                },
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Salvar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getTipoMeta(tipoSelecionado).cor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _adicionarProgresso(Map<String, dynamic> meta) async {
    final valorController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_chart, color: Colors.orange),
            ),
            const SizedBox(width: 12),
            const Text('Adicionar Progresso'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Meta: ${meta['titulo']?.toString() ?? ''}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: valorController,
              decoration: InputDecoration(
                labelText: 'Valor a adicionar',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixText: 'R\$ ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (result == true && valorController.text.isNotEmpty) {
      try {
        String valorStr = valorController.text
            .replaceAll('R\$', '')
            .replaceAll(' ', '')
            .replaceAll(',', '.')
            .trim();
        final valorAdicional = double.parse(valorStr);
        final valorAtualAtual = (meta['valor_atual'] as num?)?.toDouble() ?? 0;
        final novoValorAtual = valorAtualAtual + valorAdicional;

        await _metaRepo.atualizarProgressoMeta(
            meta['id'] as int, novoValorAtual);

        final valorObjetivo = (meta['valor_objetivo'] as num?)?.toDouble() ?? 0;
        if (novoValorAtual >= valorObjetivo) {
          await _metaRepo.concluirMeta(meta['id'] as int);
        }

        await _carregarDados();
        if (mounted) {
          Toast.success(context, 'Progresso atualizado! 🎯');
        }
      } catch (e) {
        if (mounted) {
          Toast.error(context, 'Valor inválido');
        }
      }
    }
  }

  Future<void> _excluirMeta(int id, String titulo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir Meta'),
        content:
            Text('Deseja excluir "$titulo"?\nEsta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _metaRepo.deleteMeta(id);
        await _carregarDados();
        if (mounted) {
          Toast.success(context, '$titulo excluída!');
        }
      } catch (e) {
        if (mounted) {
          Toast.error(context, 'Erro ao excluir');
        }
      }
    }
  }

  TipoMeta _getTipoMeta(String? tipo) {
    return TipoMetaExtension.fromString(tipo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary(context),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarDados,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_resumo != null) _buildResumo(),
                _buildFiltrosStatus(),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_metasFiltradas.length} meta(s)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _adicionarMeta,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Nova Meta'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _metasFiltradas.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _carregarDados,
                          child: GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 2.1,
                            ),
                            itemCount: _metasFiltradas.length,
                            itemBuilder: (context, index) {
                              return _buildMetaCard(_metasFiltradas[index]);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildResumo() {
    if (_resumo == null) return const SizedBox.shrink();

    final total = (_resumo!['total'] as num?)?.toInt() ?? 0;
    final concluidas = (_resumo!['concluidas'] as num?)?.toInt() ?? 0;
    final emAndamento = (_resumo!['emAndamento'] as num?)?.toInt() ?? 0;
    final progressoGeral =
        (_resumo!['progressoGeral'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withValues(alpha: 0.8), AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildResumoItem('Total', '$total', Icons.flag),
              _buildResumoItem('Concluídas', '$concluidas', Icons.check_circle),
              _buildResumoItem(
                  'Em Andamento', '$emAndamento', Icons.trending_up),
            ],
          ),
          if (progressoGeral > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (progressoGeral / 100).clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      color: Colors.white,
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${progressoGeral.toStringAsFixed(1)}%',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResumoItem(String label, String valor, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          valor,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildFiltrosStatus() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildChipFiltro('Todas', 'todas'),
          const SizedBox(width: 8),
          _buildChipFiltro('Em Andamento', 'andamento'),
          const SizedBox(width: 8),
          _buildChipFiltro('Concluídas', 'concluidas'),
        ],
      ),
    );
  }

  Widget _buildChipFiltro(String label, String status) {
    final selecionado = _filtroStatus == status;
    return GestureDetector(
      onTap: () => setState(() => _filtroStatus = status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selecionado ? AppColors.primary : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selecionado ? Colors.white : Colors.grey[700],
            fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
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
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.flag, size: 64, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            _filtroStatus == 'todas'
                ? 'Nenhuma meta cadastrada'
                : 'Nenhuma meta encontrada',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Clique no botão + para criar sua primeira meta',
            style: TextStyle(fontSize: 12, color: AppColors.textHint(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaCard(Map<String, dynamic> meta) {
    final titulo = meta['titulo']?.toString() ?? 'Sem título';
    final descricao = meta['descricao']?.toString() ?? '';
    final valorObjetivo = (meta['valor_objetivo'] as num?)?.toDouble() ?? 0;
    final valorAtual = (meta['valor_atual'] as num?)?.toDouble() ?? 0;
    final progresso = valorObjetivo > 0 ? (valorAtual / valorObjetivo) : 0;
    final percentual = (progresso * 100).clamp(0, 100);
    final dataFim = meta['data_fim'] != null
        ? DateTime.parse(meta['data_fim'].toString())
        : DateTime.now();
    final tipoMeta = _getTipoMeta(meta['cor']?.toString());
    final diasRestantes = dataFim.difference(DateTime.now()).inDays;
    final estaConcluida = meta['concluida'] == 1 || valorAtual >= valorObjetivo;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      shadowColor: tipoMeta.cor.withValues(alpha: 0.3),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              tipoMeta.cor.withValues(alpha: 0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabeçalho
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [tipoMeta.cor.withValues(alpha: 0.7), tipoMeta.cor],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(tipoMeta.emoji,
                        style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (descricao.isNotEmpty)
                        Text(
                          descricao,
                          style:
                              TextStyle(fontSize: 10, color: Colors.grey[500]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: estaConcluida
                    ? Colors.green.withOpacity(0.1)
                    : diasRestantes < 0
                        ? Colors.red.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                estaConcluida
                    ? 'Concluída'
                    : diasRestantes < 0
                        ? 'Atrasada'
                        : 'Em andamento',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: estaConcluida
                      ? Colors.green
                      : diasRestantes < 0
                          ? Colors.red
                          : Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Tipo e data
            Text(
              '${tipoMeta.nome} - Até ${DateFormat('dd/MM/yy').format(dataFim)}',
              style: TextStyle(fontSize: 9, color: Colors.grey[500]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // Valores
            Text(
              Formatador.moeda(valorAtual),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Text(
              Formatador.moeda(valorObjetivo),
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            const SizedBox(height: 6),

            // Barra de progresso
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (progresso.clamp(0.0, 1.0)).toDouble(),
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  estaConcluida ? Colors.green : tipoMeta.cor,
                ),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 4),

            // Percentual
            Text(
              '${percentual.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: tipoMeta.cor,
              ),
            ),
            const SizedBox(height: 6),

            // Botão Depositar
            SizedBox(
              width: double.infinity,
              height: 28,
              child: ElevatedButton.icon(
                onPressed:
                    estaConcluida ? null : () => _adicionarProgresso(meta),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Depositar', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tipoMeta.cor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            const Spacer(),

            // Ações
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () => _editarMeta(meta),
                  child: Icon(Icons.edit_outlined,
                      size: 16, color: Colors.grey[500]),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _excluirMeta(meta['id'] as int, titulo),
                  child: Icon(Icons.delete_outline,
                      size: 16, color: Colors.red[300]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
