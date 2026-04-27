// lib/screens/metas_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';
import '../services/logger_service.dart';
import '../widgets/toast.dart';
import '../widgets/animated_counter.dart';

class MetasScreen extends StatefulWidget {
  const MetasScreen({super.key});

  @override
  State<MetasScreen> createState() => _MetasScreenState();
}

class _MetasScreenState extends State<MetasScreen> {
  final DBHelper _dbHelper = DBHelper();

  List<Map<String, dynamic>> _metas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarMetas();
  }

  Future<void> _carregarMetas() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      _metas = await _dbHelper.getAllMetas();
    } catch (e) {
      LoggerService.error('Erro ao carregar metas: $e');
      if (mounted) {
        Toast.error(context, 'Erro ao carregar: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _adicionarMeta() async {
    final resultado = await _mostrarModalMeta();
    if (resultado != null) {
      await _salvarMeta(resultado);
      await _carregarMetas();
    }
  }

  Future<void> _editarMeta(Map<String, dynamic> meta) async {
    final resultado = await _mostrarModalMeta(meta: meta);
    if (resultado != null) {
      await _atualizarMeta(resultado);
      await _carregarMetas();
    }
  }

  Future<Map<String, dynamic>?> _mostrarModalMeta(
      {Map<String, dynamic>? meta}) async {
    final tituloController = TextEditingController(text: meta?['titulo'] ?? '');
    final descricaoController =
        TextEditingController(text: meta?['descricao'] ?? '');
    final valorObjetivoController =
        TextEditingController(text: meta?['valor_objetivo']?.toString() ?? '');
    final valorAtualController =
        TextEditingController(text: meta?['valor_atual']?.toString() ?? '');
    final dataFimController = TextEditingController();
    String cor = meta?['cor'] ?? '#4CAF50';
    String icone = meta?['icone'] ?? 'ðŸŽ¯';
    DateTime? dataInicio;
    DateTime? dataFim;

    dataInicio = meta != null && meta['data_inicio'] != null
        ? DateTime.parse(meta['data_inicio'])
        : DateTime.now();

    if (meta?['data_fim'] != null) {
      dataFim = DateTime.parse(meta!['data_fim']);
      dataFimController.text = DateFormat('dd/MM/yyyy').format(dataFim);
    }

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(meta == null ? 'Nova Meta' : 'Editar Meta'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: tituloController,
                    decoration: const InputDecoration(
                      labelText: 'Titulo da Meta',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descricaoController,
                    decoration: const InputDecoration(
                      labelText: 'Descricao (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: valorObjetivoController,
                    decoration: const InputDecoration(
                      labelText: 'Valor Objetivo',
                      border: OutlineInputBorder(),
                      prefixText: 'R\$ ',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: valorAtualController,
                    decoration: const InputDecoration(
                      labelText: 'Valor Atual (opcional)',
                      border: OutlineInputBorder(),
                      prefixText: 'R\$ ',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Data de inicio: ${DateFormat('dd/MM/yyyy').format(dataInicio!)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        Icon(Icons.calendar_today,
                            size: 18, color: Colors.grey[600]),
                      ],
                    ),
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
                        dataFim = picked;
                        dataFimController.text =
                            DateFormat('dd/MM/yyyy').format(picked);
                        setStateDialog(() {});
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dataFimController.text.isEmpty
                                ? 'Data de conclusao'
                                : dataFimController.text,
                            style: TextStyle(
                              color: dataFimController.text.isEmpty
                                  ? Colors.grey
                                  : Colors.black,
                            ),
                          ),
                          const Icon(Icons.calendar_today, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: cor, // âœ… CORRIGIDO: initialValue -> value
                    decoration: const InputDecoration(
                      labelText: 'Cor',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      '#4CAF50',
                      '#2196F3',
                      '#FF9800',
                      '#F44336',
                      '#9C27B0',
                      '#00BCD4'
                    ].map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Color(
                                    int.parse(c.replaceFirst('#', '0xFF'))),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(c),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setStateDialog(() => cor = value!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  final titulo = tituloController.text.trim();
                  if (titulo.isEmpty) {
                    Toast.warning(context, 'Digite o titulo da meta');
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
                    Toast.error(context,
                        'Valor invalido. Use numeros como: 1000 ou 1000,50');
                    return;
                  }

                  if (dataFim == null) {
                    Toast.warning(context, 'Selecione a data de conclusao');
                    return;
                  }

                  Navigator.pop(context, {
                    'id': meta?['id'],
                    'titulo': titulo,
                    'descricao': descricaoController.text.trim(),
                    'valor_objetivo': valorObjetivo,
                    'valor_atual': valorAtual,
                    'data_inicio': DateFormat('yyyy-MM-dd').format(dataInicio!),
                    'data_fim': DateFormat('yyyy-MM-dd').format(dataFim!),
                    'cor': cor,
                    'icone': icone,
                    'concluida': meta?['concluida'] ?? 0,
                  });
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _salvarMeta(Map<String, dynamic> meta) async {
    try {
      await _dbHelper.insertMeta(meta);
      if (mounted) {
        Toast.success(context, '${meta['titulo']} adicionada!');
      }
    } catch (e) {
      if (mounted) {
        Toast.error(context, 'Erro ao salvar: $e');
      }
      LoggerService.error('Erro ao salvar meta: $e');
    }
  }

  Future<void> _atualizarMeta(Map<String, dynamic> meta) async {
    try {
      await _dbHelper.updateMeta(meta);
      if (mounted) {
        Toast.success(context, '${meta['titulo']} atualizada!');
      }
    } catch (e) {
      if (mounted) {
        Toast.error(context, 'Erro ao atualizar: $e');
      }
      LoggerService.error('Erro ao atualizar meta: $e');
    }
  }

  Future<void> _excluirMeta(int id, String titulo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
          Toast.success(context, '$titulo excluida!');
        }
      } catch (e) {
        if (mounted) {
          Toast.error(context, 'Erro ao excluir: $e');
        }
      }
    }
  }

  Future<void> _atualizarProgresso(Map<String, dynamic> meta) async {
    final valorController = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar Progresso'),
        content: TextField(
          controller: valorController,
          decoration: const InputDecoration(
            labelText: 'Valor a adicionar',
            border: OutlineInputBorder(),
            prefixText: 'R\$ ',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (confirmar == true && valorController.text.isNotEmpty) {
      try {
        String valorStr = valorController.text
            .replaceAll('R\$', '')
            .replaceAll(' ', '')
            .replaceAll(',', '.')
            .trim();

        final valorAdicional = double.parse(valorStr);
        final novoValorAtual =
            (meta['valor_atual'] as num).toDouble() + valorAdicional;

        await _dbHelper.atualizarProgressoMeta(meta['id'], novoValorAtual);
        await _carregarMetas();

        if (mounted) {
          Toast.success(context, 'Progresso atualizado!');
        }
      } catch (e) {
        if (mounted) {
          Toast.error(context, 'Valor invalido');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Metas'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary(context),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarMetas,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _metas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flag,
                          size: 64, color: AppColors.muted(context)),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhuma meta cadastrada',
                        style:
                            TextStyle(color: AppColors.textSecondary(context)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Clique no botao + para criar sua primeira meta',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textHint(context)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _metas.length,
                  itemBuilder: (context, index) {
                    final meta = _metas[index];
                    return _buildMetaCard(meta);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _adicionarMeta,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMetaCard(Map<String, dynamic> meta) {
    final titulo = meta['titulo'] ?? 'Sem titulo';
    final descricao = meta['descricao'] ?? '';
    final valorObjetivo = (meta['valor_objetivo'] as num?)?.toDouble() ?? 0;
    final valorAtual = (meta['valor_atual'] as num?)?.toDouble() ?? 0;
    final progresso = valorObjetivo > 0 ? (valorAtual / valorObjetivo) : 0;
    final percentual = (progresso * 100).clamp(0, 100);
    final dataInicio = meta['data_inicio'] != null
        ? DateTime.parse(meta['data_inicio'].toString())
        : DateTime.now();
    final dataFim = DateTime.parse(meta['data_fim'].toString());
    final corHex = meta['cor'] ?? '#4CAF50';
    final cor = Color(int.parse(corHex.replaceFirst('#', '0xFF')));
    final diasRestantes = dataFim.difference(DateTime.now()).inDays;
    final estaConcluida = meta['concluida'] == 1 || valorAtual >= valorObjetivo;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (descricao.isNotEmpty)
                        Text(
                          descricao,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'Objetivo: ${Formatador.moeda(valorObjetivo)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (estaConcluida)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green),
                        SizedBox(width: 4),
                        Text('Concluida',
                            style:
                                TextStyle(fontSize: 10, color: Colors.green)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progresso: ${percentual.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  '${Formatador.moeda(valorAtual)} / ${Formatador.moeda(valorObjetivo)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (valorObjetivo > 0 ? (valorAtual / valorObjetivo) : 0.0)
                    .clamp(0.0, 1.0),
                backgroundColor: Colors.grey[200],
                color: cor,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Inicio: ${DateFormat('dd/MM/yyyy').format(dataInicio)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.flag, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Fim: ${DateFormat('dd/MM/yyyy').format(dataFim)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (diasRestantes > 0 && !estaConcluida)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$diasRestantes dias restantes',
                      style:
                          const TextStyle(fontSize: 10, color: Colors.orange),
                    ),
                  ),
                if (diasRestantes < 0 && !estaConcluida)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Atrasada',
                      style: TextStyle(fontSize: 10, color: Colors.red),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!estaConcluida)
                  ElevatedButton.icon(
                    onPressed: () => _atualizarProgresso(meta),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Progresso'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: const Size(0, 32),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _editarMeta(meta),
                  icon: const Icon(Icons.edit, size: 18),
                  tooltip: 'Editar',
                ),
                IconButton(
                  onPressed: () => _excluirMeta(meta['id'], titulo),
                  icon: const Icon(Icons.delete, size: 18),
                  tooltip: 'Excluir',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

