// lib/widgets/detalhes_meta_modal.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';
import 'adicionar_deposito_modal.dart';
import 'editar_meta_modal.dart';

class DetalhesMetaModal extends StatefulWidget {
  final Map<String, dynamic> meta;
  final Future<void> Function()? onMetaAlterada;

  const DetalhesMetaModal({super.key, required this.meta, this.onMetaAlterada});

  @override
  State<DetalhesMetaModal> createState() => _DetalhesMetaModalState();

  static Future<void> show(
      {required BuildContext context,
      required Map<String, dynamic> meta,
      Future<void> Function()? onMetaAlterada}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: DetalhesMetaModal(meta: meta, onMetaAlterada: onMetaAlterada),
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
        setState(() => metaAtual = metaAtualizada);
      }
    } catch (e) {
      debugPrint('Erro: $e');
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  String _formatarValor(double valor) => Formatador.moeda(valor);
  Color _getCorPorTipo(String? cor) => switch (cor) {
        'viagem' => Colors.blue,
        'carro' => Colors.red,
        'casa' => Colors.green,
        'estudo' => Colors.orange,
        'investimento' => Colors.purple,
        _ => const Color(0xFF7B2CBF)
      };
  IconData _getIconePorTipo(String? icone) => switch (icone) {
        'viagem' => Icons.flight,
        'carro' => Icons.directions_car,
        'casa' => Icons.home,
        'estudo' => Icons.school,
        'investimento' => Icons.trending_up,
        _ => Icons.flag
      };

  Future<void> _adicionarDeposito() async => AdicionarDepositoModal.show(
      context: context,
      metaId: metaAtual['id'],
      valorAtual: (metaAtual['valor_atual'] ?? 0).toDouble(),
      valorObjetivo: (metaAtual['valor_objetivo'] ?? 0).toDouble(),
      onDepositoAdicionado: () async {
        await _carregarDepositos();
        if (widget.onMetaAlterada != null) await widget.onMetaAlterada!();
      });
  Future<void> _editarMeta() async => EditarMetaModal.show(
      context: context,
      meta: metaAtual,
      onSalvo: () async {
        await _carregarDepositos();
        if (widget.onMetaAlterada != null) await widget.onMetaAlterada!();
      });
  Future<void> _excluirMeta() async {
    if (await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
                    title: const Text('Excluir Meta'),
                    content: Text('Excluir "${metaAtual['titulo']}"?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Excluir',
                              style: TextStyle(color: Colors.red)))
                    ])) ==
        true) {
      await _dbHelper.deleteMeta(metaAtual['id']);
      if (widget.onMetaAlterada != null) await widget.onMetaAlterada!();
      if (mounted) Navigator.pop(context);
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

    return Container(
      width: MediaQuery.of(context).size.width - 40,
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(metaAtual['titulo'] ?? 'Detalhes da Meta', context,
              () => _editarMeta(), () => _excluirMeta()),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey[200]!)),
                      child: Column(children: [
                        Row(children: [
                          Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                  color: cor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(15)),
                              child: Icon(icone, color: cor, size: 30)),
                          const SizedBox(width: 15),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(metaAtual['titulo'] ?? 'Sem título',
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold)),
                                if (metaAtual['descricao'] != null &&
                                    metaAtual['descricao']
                                        .toString()
                                        .isNotEmpty)
                                  Text(metaAtual['descricao'],
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF666666)))
                              ]))
                        ]),
                        const SizedBox(height: 20),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Progresso',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                              Text('${percentual.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: percentual >= 100
                                          ? Colors.green
                                          : cor))
                            ]),
                        const SizedBox(height: 8),
                        ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                                value: progresso.clamp(0.0, 1.0),
                                backgroundColor: Colors.grey[200],
                                color: percentual >= 100 ? Colors.green : cor,
                                minHeight: 12)),
                        const SizedBox(height: 16),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Valor Atual',
                                        style: TextStyle(fontSize: 12)),
                                    Text(_formatarValor(valorAtual),
                                        style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: cor))
                                  ]),
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Meta',
                                        style: TextStyle(fontSize: 12)),
                                    Text(_formatarValor(valorObjetivo),
                                        style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold))
                                  ])
                            ]),
                        const SizedBox(height: 20),
                        Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!)),
                            child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(children: [
                                    Icon(Icons.calendar_today, size: 16),
                                    SizedBox(width: 8),
                                    Text('Data limite:')
                                  ]),
                                  Text(
                                      Formatador.data(DateTime.parse(
                                          metaAtual['data_fim'])),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold))
                                ])),
                        const SizedBox(height: 16),
                        Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: cor.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: cor.withValues(alpha: 0.2))),
                            child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(children: [
                                    Icon(Icons.trending_up, color: cor),
                                    const SizedBox(width: 8),
                                    const Text('Falta alcançar:')
                                  ]),
                                  Text(
                                      _formatarValor(
                                          (valorObjetivo - valorAtual)
                                              .clamp(0, valorObjetivo)),
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: cor))
                                ])),
                      ])),
                  const SizedBox(height: 16),
                  if (!concluida)
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                            onPressed: _adicionarDeposito,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7B2CBF),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))),
                            child: const Text('ADICIONAR DEPÓSITO'))),
                  const SizedBox(height: 16),
                  Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey[200]!)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Histórico de Depósitos',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                  if (depositos.isNotEmpty)
                                    Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                            color: cor.withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: Text(
                                            '${depositos.length} ${depositos.length == 1 ? 'depósito' : 'depósitos'}',
                                            style: TextStyle(color: cor)))
                                ]),
                            const SizedBox(height: 16),
                            if (depositos.isEmpty)
                              const Center(
                                  child: Column(children: [
                                Icon(Icons.history,
                                    size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Nenhum depósito ainda'),
                                Text('Clique no botão acima para começar',
                                    style: TextStyle(fontSize: 12))
                              ])),
                            ...depositos.map((d) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.grey[200]!)),
                                child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(children: [
                                        Icon(Icons.paid, color: cor),
                                        const SizedBox(width: 12),
                                        Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  _formatarValor(
                                                      (d['valor'] ?? 0)
                                                          .toDouble()),
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              Text(
                                                  Formatador.data(
                                                      DateTime.parse(
                                                          d['data_deposito'])),
                                                  style: const TextStyle(
                                                      fontSize: 11))
                                            ])
                                      ]),
                                      if (d['observacao'] != null &&
                                          d['observacao'].toString().isNotEmpty)
                                        Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                                color:
                                                    cor.withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                            child: Text(d['observacao'],
                                                style: TextStyle(color: cor)))
                                    ]))),
                          ])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title, BuildContext context, VoidCallback onEdit,
      VoidCallback onDelete) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
          Row(children: [
            IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 20),
                color: Colors.grey[600]),
            IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete, size: 20),
                color: Colors.grey[600]),
            GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close, size: 20, color: Colors.grey[500])),
          ]),
        ],
      ),
    );
  }
}
