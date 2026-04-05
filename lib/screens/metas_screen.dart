// lib/screens/metas_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../models/meta_model.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';

class MetasScreen extends StatefulWidget {
  const MetasScreen({super.key});

  @override
  State<MetasScreen> createState() => _MetasScreenState();
}

class _MetasScreenState extends State<MetasScreen> {
  late final SupabaseService _supabaseService;

  List<Meta> _metas = [];
  bool _carregando = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _supabaseService = Provider.of<SupabaseService>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    _carregarMetas();
  }

  Future<void> _carregarMetas() async {
    if (!mounted) return;
    setState(() => _carregando = true);

    try {
      _metas = await _supabaseService.getMetas();
    } catch (e) {
      debugPrint('❌ Erro ao carregar metas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao carregar metas: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _adicionarMeta() async {
    final tituloCtrl = TextEditingController();
    final descricaoCtrl = TextEditingController();
    final valorCtrl = TextEditingController();
    DateTime dataFim = DateTime.now().add(const Duration(days: 30));
    TipoMeta tipoSelecionado = TipoMeta.viagem;

    final opcoesTipo = TipoMeta.values;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
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
                      const Text('Nova Meta',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tipo da meta',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 60,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: opcoesTipo.length,
                            itemBuilder: (context, index) {
                              final opcao = opcoesTipo[index];
                              final isSelected = tipoSelecionado == opcao;
                              return GestureDetector(
                                onTap: () => setStateModal(
                                    () => tipoSelecionado = opcao),
                                child: Container(
                                  width: 70,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? opcao.cor.withOpacity(0.2)
                                        : AppColors.muted(context),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: isSelected
                                            ? opcao.cor
                                            : AppColors.border(context),
                                        width: isSelected ? 2 : 1),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(opcao.icone,
                                          color: isSelected
                                              ? opcao.cor
                                              : AppColors.textSecondary(
                                                  context),
                                          size: 24),
                                      const SizedBox(height: 4),
                                      Text(opcao.nome,
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: isSelected
                                                  ? opcao.cor
                                                  : AppColors.textSecondary(
                                                      context),
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text('Título',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: tituloCtrl,
                          decoration: const InputDecoration(
                              hintText: 'Ex: Viagem para a praia',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.title)),
                        ),
                        const SizedBox(height: 16),
                        const Text('Descrição (opcional)',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: descricaoCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                              hintText:
                                  'Ex: Guardar dinheiro para viajar em dezembro',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.description)),
                        ),
                        const SizedBox(height: 16),
                        const Text('Valor da meta',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: valorCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              hintText: '0,00',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.attach_money),
                              prefixText: 'R\$ '),
                        ),
                        const SizedBox(height: 16),
                        const Text('Data limite',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: dataFim,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365 * 5)),
                            );
                            if (picked != null)
                              setStateModal(() => dataFim = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today,
                                    color: AppColors.primary),
                                const SizedBox(width: 12),
                                Text(Formatador.data(dataFim)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Cancelar',
                                    style: TextStyle(
                                        color:
                                            AppColors.textSecondary(context))),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (tituloCtrl.text.isEmpty ||
                                      valorCtrl.text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Preencha título e valor!')),
                                    );
                                    return;
                                  }
                                  final valor = double.parse(
                                      valorCtrl.text.replaceAll(',', '.'));
                                  if (valor <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Digite um valor válido!')),
                                    );
                                    return;
                                  }
                                  Navigator.pop(context);
                                  final novaMeta = Meta(
                                    titulo: tituloCtrl.text,
                                    descricao: descricaoCtrl.text,
                                    valorObjetivo: valor,
                                    dataInicio: DateTime.now(),
                                    dataFim: dataFim,
                                    tipo: tipoSelecionado,
                                  );
                                  try {
                                    await _supabaseService.addMeta(novaMeta);
                                    await _carregarMetas();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                '🎯 Meta criada com sucesso!'),
                                            backgroundColor: AppColors.success),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text('Erro: $e'),
                                            backgroundColor: AppColors.error),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary),
                                child: const Text('CRIAR META',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
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

  Future<void> _editarMeta(Meta meta) async {
    final tituloCtrl = TextEditingController(text: meta.titulo);
    final descricaoCtrl = TextEditingController(text: meta.descricao ?? '');
    final valorCtrl = TextEditingController(
        text: meta.valorObjetivo.toString().replaceAll('.', ','));
    DateTime dataFim = meta.dataFim;
    TipoMeta tipoSelecionado = meta.tipo;

    final opcoesTipo = TipoMeta.values;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
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
                      const Text('Editar Meta',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tipo da meta',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 60,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: opcoesTipo.length,
                            itemBuilder: (context, index) {
                              final opcao = opcoesTipo[index];
                              final isSelected = tipoSelecionado == opcao;
                              return GestureDetector(
                                onTap: () => setStateModal(
                                    () => tipoSelecionado = opcao),
                                child: Container(
                                  width: 70,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? opcao.cor.withOpacity(0.2)
                                        : AppColors.muted(context),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: isSelected
                                            ? opcao.cor
                                            : AppColors.border(context),
                                        width: isSelected ? 2 : 1),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(opcao.icone,
                                          color: isSelected
                                              ? opcao.cor
                                              : AppColors.textSecondary(
                                                  context),
                                          size: 24),
                                      const SizedBox(height: 4),
                                      Text(opcao.nome,
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: isSelected
                                                  ? opcao.cor
                                                  : AppColors.textSecondary(
                                                      context),
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text('Título',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextField(
                            controller: tituloCtrl,
                            decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.title))),
                        const SizedBox(height: 16),
                        const Text('Descrição (opcional)',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextField(
                            controller: descricaoCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.description))),
                        const SizedBox(height: 16),
                        const Text('Valor da meta',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextField(
                            controller: valorCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.attach_money),
                                prefixText: 'R\$ ')),
                        const SizedBox(height: 16),
                        const Text('Data limite',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: dataFim,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365 * 5)),
                            );
                            if (picked != null)
                              setStateModal(() => dataFim = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today,
                                    color: AppColors.primary),
                                const SizedBox(width: 12),
                                Text(Formatador.data(dataFim)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Excluir Meta'),
                                      content: Text(
                                          'Deseja excluir "${meta.titulo}"?'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancelar')),
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Excluir',
                                                style: TextStyle(
                                                    color: Colors.red))),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    Navigator.pop(context);
                                    try {
                                      await _supabaseService
                                          .deleteMeta(meta.id!);
                                      await _carregarMetas();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content:
                                                  Text('🗑️ Meta excluída!'),
                                              backgroundColor: Colors.orange),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text('Erro: $e'),
                                              backgroundColor: AppColors.error),
                                        );
                                      }
                                    }
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red),
                                child: const Text('EXCLUIR'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (tituloCtrl.text.isEmpty ||
                                      valorCtrl.text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Preencha título e valor!')),
                                    );
                                    return;
                                  }
                                  final valor = double.parse(
                                      valorCtrl.text.replaceAll(',', '.'));
                                  if (valor <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Digite um valor válido!')),
                                    );
                                    return;
                                  }
                                  Navigator.pop(context);
                                  final metaAtualizada = Meta(
                                    id: meta.id,
                                    titulo: tituloCtrl.text,
                                    descricao: descricaoCtrl.text,
                                    valorObjetivo: valor,
                                    valorAtual: meta.valorAtual,
                                    dataInicio: meta.dataInicio,
                                    dataFim: dataFim,
                                    tipo: tipoSelecionado,
                                    concluida: meta.concluida,
                                  );
                                  try {
                                    await _supabaseService
                                        .updateMeta(metaAtualizada);
                                    await _carregarMetas();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text('✏️ Meta atualizada!'),
                                            backgroundColor: AppColors.success),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text('Erro: $e'),
                                            backgroundColor: AppColors.error),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary),
                                child: const Text('SALVAR',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
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

  Future<void> _adicionarDeposito(Meta meta) async {
    final valorCtrl = TextEditingController();
    final observacaoCtrl = TextEditingController();
    // 🔥 CORRIGIDO: adicionado .toDouble()
    final valorRestante = (meta.valorObjetivo - meta.valorAtual)
        .clamp(0.0, meta.valorObjetivo)
        .toDouble();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.6,
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
                      const Text('Adicionar Depósito',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Progresso atual:',
                                        style: TextStyle(
                                            color: AppColors.textSecondary(
                                                context))),
                                    Text(Formatador.moeda(meta.valorAtual),
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary(
                                                context))),
                                  ]),
                              const SizedBox(height: 8),
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Falta:',
                                        style: TextStyle(
                                            color: AppColors.textSecondary(
                                                context))),
                                    Text(Formatador.moeda(valorRestante),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                            fontSize: 16)),
                                  ]),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text('Valor do depósito',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: valorCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              hintText: '0,00',
                              prefixIcon: Icon(Icons.attach_money),
                              prefixText: 'R\$ ',
                              border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        const Text('Observação (opcional)',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextField(
                            controller: observacaoCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                                hintText: 'Ex: Depósito mensal',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.note))),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                                child: TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text('Cancelar',
                                        style: TextStyle(
                                            color: AppColors.textSecondary(
                                                context))))),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (valorCtrl.text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Digite o valor!')),
                                    );
                                    return;
                                  }
                                  final valor = double.parse(
                                      valorCtrl.text.replaceAll(',', '.'));
                                  if (valor <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Valor inválido!')),
                                    );
                                    return;
                                  }
                                  if (valor > valorRestante) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Valor excede a meta (Máx: ${Formatador.moeda(valorRestante)})'),
                                          backgroundColor: Colors.orange),
                                    );
                                    return;
                                  }
                                  Navigator.pop(context);
                                  try {
                                    await _supabaseService.addDeposito(
                                        meta.id!, valor, observacaoCtrl.text);
                                    await _carregarMetas();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('✅ Depósito adicionado!'),
                                            backgroundColor: AppColors.success),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text('Erro: $e'),
                                            backgroundColor: AppColors.error),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary),
                                child: const Text('ADICIONAR',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
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

  Future<void> _verDetalhesMeta(Meta meta) async {
    final depositos = await _supabaseService.getDepositos(meta.id!);
    final valorAtual = meta.valorAtual;
    final valorObjetivo = meta.valorObjetivo;
    final progresso = valorObjetivo > 0 ? (valorAtual / valorObjetivo) : 0.0;
    final percentual = (progresso * 100).clamp(0, 100);
    final cor = meta.tipo.cor;
    final icone = meta.tipo.icone;
    final concluida = meta.concluida;

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
                          child: Text(meta.titulo,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                      Row(
                        children: [
                          IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              color: Colors.white,
                              onPressed: () {
                                Navigator.pop(context);
                                _editarMeta(meta);
                              }),
                          IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              color: Colors.white,
                              onPressed: () async {
                                Navigator.pop(context);
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Excluir Meta'),
                                    content: Text(
                                        'Deseja excluir "${meta.titulo}"?'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancelar')),
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Excluir',
                                              style: TextStyle(
                                                  color: Colors.red))),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  try {
                                    await _supabaseService.deleteMeta(meta.id!);
                                    await _carregarMetas();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text('🗑️ Meta excluída!'),
                                            backgroundColor: Colors.orange),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text('Erro: $e'),
                                            backgroundColor: AppColors.error),
                                      );
                                    }
                                  }
                                }
                              }),
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
                              Row(children: [
                                Container(
                                    padding: const EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                        color: cor.withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(15)),
                                    child: Icon(icone, color: cor, size: 30)),
                                const SizedBox(width: 15),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(meta.titulo,
                                          style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary(
                                                  context))),
                                      if (meta.descricao != null &&
                                          meta.descricao!.isNotEmpty)
                                        Text(meta.descricao!,
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: AppColors.textSecondary(
                                                    context))),
                                    ])),
                                if (concluida)
                                  Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                          color: AppColors.success
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: const Row(children: [
                                        Icon(Icons.check_circle,
                                            color: AppColors.success, size: 16),
                                        SizedBox(width: 4),
                                        Text('Concluída',
                                            style: TextStyle(
                                                color: AppColors.success,
                                                fontWeight: FontWeight.bold))
                                      ])),
                              ]),
                              const SizedBox(height: 20),
                              Divider(color: AppColors.divider(context)),
                              const SizedBox(height: 10),
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Progresso',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary(
                                                context))),
                                    Text('${percentual.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: percentual >= 100
                                                ? AppColors.success
                                                : cor)),
                                  ]),
                              const SizedBox(height: 8),
                              ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                      value: progresso.clamp(0.0, 1.0),
                                      backgroundColor: AppColors.muted(context),
                                      color: percentual >= 100
                                          ? AppColors.success
                                          : cor,
                                      minHeight: 12)),
                              const SizedBox(height: 16),
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Valor Atual',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary(
                                                          context))),
                                          const SizedBox(height: 4),
                                          Text(Formatador.moeda(valorAtual),
                                              style: TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                  color: cor)),
                                        ]),
                                    Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text('Meta',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary(
                                                          context))),
                                          const SizedBox(height: 4),
                                          Text(Formatador.moeda(valorObjetivo),
                                              style: TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textPrimary(
                                                      context))),
                                        ]),
                                  ]),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: AppColors.surface(context),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: AppColors.border(context))),
                                child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(children: [
                                        Icon(Icons.calendar_today,
                                            size: 16,
                                            color: AppColors.textSecondary(
                                                context)),
                                        const SizedBox(width: 8),
                                        Text('Data limite:',
                                            style: TextStyle(
                                                color: AppColors.textSecondary(
                                                    context)))
                                      ]),
                                      Text(Formatador.data(meta.dataFim),
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary(
                                                  context))),
                                    ]),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: cor.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: cor.withOpacity(0.2))),
                                child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(children: [
                                        Icon(Icons.trending_up,
                                            color: cor, size: 20),
                                        const SizedBox(width: 8),
                                        Text('Falta alcançar:',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.textPrimary(
                                                    context)))
                                      ]),
                                      // 🔥 CORRIGIDO: adicionado .toDouble()
                                      Text(
                                          Formatador.moeda(
                                              (valorObjetivo - valorAtual)
                                                  .clamp(0, valorObjetivo)
                                                  .toDouble()),
                                          style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: cor)),
                                    ]),
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
                                      backgroundColor: AppColors.primary),
                                  child: const Text('ADICIONAR DEPÓSITO',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)))),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              color: AppColors.surface(context),
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: AppColors.border(context))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Histórico de Depósitos',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary(
                                                context))),
                                    if (depositos.isNotEmpty)
                                      Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                              color: cor.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          child: Text(
                                              '${depositos.length} ${depositos.length == 1 ? 'depósito' : 'depósitos'}',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: cor,
                                                  fontWeight:
                                                      FontWeight.bold))),
                                  ]),
                              const SizedBox(height: 16),
                              if (depositos.isEmpty)
                                Center(
                                    child: Column(children: [
                                  Icon(Icons.history,
                                      size: 48,
                                      color: AppColors.muted(context)),
                                  const SizedBox(height: 8),
                                  Text('Nenhum depósito ainda',
                                      style: TextStyle(
                                          color: AppColors.textSecondary(
                                              context))),
                                  const SizedBox(height: 4),
                                  Text('Clique no botão acima para começar',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary(
                                              context))),
                                ]))
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: depositos.length,
                                  itemBuilder: (context, index) {
                                    final d = depositos[index];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                          color: AppColors.surface(context),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color:
                                                  AppColors.border(context))),
                                      child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(children: [
                                              Icon(Icons.paid,
                                                  size: 20, color: cor),
                                              const SizedBox(width: 12),
                                              Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                        Formatador.moeda(
                                                            d.valor),
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: AppColors
                                                                .textPrimary(
                                                                    context))),
                                                    Text(
                                                        Formatador.data(
                                                            d.dataDeposito),
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color: AppColors
                                                                .textSecondary(
                                                                    context))),
                                                  ]),
                                            ]),
                                            if (d.observacao != null &&
                                                d.observacao!.isNotEmpty)
                                              Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                      color:
                                                          cor.withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12)),
                                                  child: Text(d.observacao!,
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          color: cor))),
                                          ]),
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
              tooltip: 'Atualizar'),
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
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: Icon(Icons.flag_outlined,
                  size: 64, color: AppColors.primary.withOpacity(0.5))),
          const SizedBox(height: 20),
          Text('Nenhuma meta cadastrada',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context))),
          const SizedBox(height: 8),
          Text('Comece definindo seus objetivos financeiros',
              style: TextStyle(
                  fontSize: 14, color: AppColors.textSecondary(context))),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _adicionarMeta,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add, size: 18),
              SizedBox(width: 8),
              Text('CRIAR PRIMEIRA META')
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaCard(Meta meta) {
    final valorObjetivo = meta.valorObjetivo;
    final valorAtual = meta.valorAtual;
    final dataFim = meta.dataFim;
    final concluida = meta.concluida;
    final cor = meta.tipo.cor;
    final icone = meta.tipo.icone;

    final progresso = valorObjetivo > 0 ? valorAtual / valorObjetivo : 0.0;
    final percentual = (progresso * 100).clamp(0, 100);
    // 🔥 CORRIGIDO: adicionado .toDouble()
    final falta =
        (valorObjetivo - valorAtual).clamp(0, valorObjetivo).toDouble();

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
                          color: cor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(icone, color: cor, size: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(meta.titulo,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary(context))),
                        if (meta.descricao != null &&
                            meta.descricao!.isNotEmpty)
                          Text(meta.descricao!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary(context)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: statusColor.withOpacity(0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                          concluida
                              ? Icons.check_circle
                              : (diasRestantes < 0
                                  ? Icons.warning
                                  : Icons.schedule),
                          size: 12,
                          color: statusColor),
                      const SizedBox(width: 4),
                      Text(statusText,
                          style: TextStyle(
                              fontSize: 10,
                              color: statusColor,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Progresso',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary(context))),
                Text('${percentual.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: percentual >= 100 ? Colors.green : cor)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                      value: progresso.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[200],
                      color: percentual >= 100 ? Colors.green : cor,
                      minHeight: 8)),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Atual',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context))),
                  Text(Formatador.moeda(valorAtual),
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context))),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Meta',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context))),
                  Text(Formatador.moeda(valorObjetivo),
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context))),
                ]),
              ]),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Icon(Icons.calendar_today,
                      size: 12, color: AppColors.textSecondary(context)),
                  const SizedBox(width: 4),
                  Text('Até ${Formatador.data(dataFim)}',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context)))
                ]),
                if (!concluida && falta > 0)
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text('Faltam ${Formatador.moeda(falta)}',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary))),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
