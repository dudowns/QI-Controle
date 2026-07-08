// lib/screens/mobile/metas_mobile.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/meta_model.dart';
import '../../repositories/meta_repository.dart';
import '../../constants/app_colors.dart';
import '../../utils/formatters.dart';
import '../../services/logger_service.dart';
import '../../widgets/toast.dart';
import '../../widgets/app_modals.dart';
import '../../widgets/adicionar_deposito_modal.dart';
import '../../services/sync_service_improved.dart';

class MetasMobileScreen extends StatefulWidget {
  const MetasMobileScreen({super.key});

  @override
  State<MetasMobileScreen> createState() => _MetasMobileScreenState();
}

class _MetasMobileScreenState extends State<MetasMobileScreen> {
  final MetaRepository _metaRepo = MetaRepository();
  final SyncServiceImproved _syncImproved = SyncServiceImproved();

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
      // ✅ 1. PRIMEIRO carrega os dados locais
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

      // ✅ 2. DEPOIS sincroniza em background
      _syncImproved.syncAllData();
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
    final resultado = await AppModals.mostrarModalMeta(context: context);
    if (resultado != null) {
      await _metaRepo.insertMeta(resultado);
      if (mounted) {
        await _carregarDados();
      }
    }
  }

  Future<void> _editarMeta(Map<String, dynamic> meta) async {
    final resultado = await AppModals.mostrarModalMeta(
      context: context,
      meta: meta,
    );
    if (resultado != null) {
      await _metaRepo.updateMeta(resultado);
      if (mounted) {
        await _carregarDados();
      }
    }
  }

  Future<void> _adicionarDeposito(Map<String, dynamic> meta) async {
    final metaId = meta['id'] as int;
    final valorAtual = (meta['valor_atual'] as num?)?.toDouble() ?? 0;
    final valorObjetivo = (meta['valor_objetivo'] as num?)?.toDouble() ?? 0;

    await AdicionarDepositoModal.show(
      context: context,
      metaId: metaId,
      valorAtual: valorAtual,
      valorObjetivo: valorObjetivo,
      onDepositoAdicionado: () async {
        if (mounted) {
          await _carregarDados();
          Toast.success(context, '✅ Depósito adicionado!');
        }
      },
    );
  }

  Future<void> _excluirMeta(int id, String titulo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Excluir Meta'),
        content:
            Text('Deseja excluir "$titulo"?\nEsta ação não pode ser desfeita.'),
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
      try {
        await _metaRepo.deleteMeta(id);
        if (mounted) {
          await _carregarDados();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Metas',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.textPrimary(context)),
            onPressed: _carregarDados,
            tooltip: 'Atualizar',
          ),
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Icon(Icons.add_rounded,
                  color: AppColors.primary, size: 22),
              onPressed: _adicionarMeta,
              tooltip: 'Nova Meta',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_resumo != null) _buildResumo(isDark),
                _buildFiltrosStatus(isDark),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_metasFiltradas.length} meta(s)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[400] : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _metasFiltradas.isEmpty
                      ? _buildEmptyState(isDark)
                      : RefreshIndicator(
                          onRefresh: _carregarDados,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
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

  Widget _buildResumo(bool isDark) {
    if (_resumo == null) return const SizedBox.shrink();

    final total = (_resumo!['total'] as num?)?.toInt() ?? 0;
    final concluidas = (_resumo!['concluidas'] as num?)?.toInt() ?? 0;
    final emAndamento = (_resumo!['emAndamento'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withValues(alpha: 0.8), AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildResumoItem('Total', '$total', Icons.flag, isDark),
          _buildResumoItem(
              'Concluídas', '$concluidas', Icons.check_circle, isDark),
          _buildResumoItem(
              'Em Andamento', '$emAndamento', Icons.trending_up, isDark),
        ],
      ),
    );
  }

  Widget _buildResumoItem(
      String label, String valor, IconData icon, bool isDark) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(height: 2),
        Text(
          valor,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  Widget _buildFiltrosStatus(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _buildChipFiltro('Todas', 'todas', isDark),
          const SizedBox(width: 6),
          _buildChipFiltro('Em Andamento', 'andamento', isDark),
          const SizedBox(width: 6),
          _buildChipFiltro('Concluídas', 'concluidas', isDark),
        ],
      ),
    );
  }

  Widget _buildChipFiltro(String label, String status, bool isDark) {
    final selecionado = _filtroStatus == status;

    return GestureDetector(
      onTap: () => setState(() => _filtroStatus = status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selecionado
              ? AppColors.primary
              : (isDark ? const Color(0xFF2A2A2A) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selecionado
                ? AppColors.primary
                : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selecionado
                ? Colors.white
                : (isDark ? Colors.grey[400] : Colors.grey[600]),
            fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.flag, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            _filtroStatus == 'todas'
                ? 'Nenhuma meta cadastrada'
                : 'Nenhuma meta encontrada',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Clique no + para criar sua primeira meta',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaCard(Map<String, dynamic> meta) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [tipoMeta.cor.withValues(alpha: 0.7), tipoMeta.cor],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(tipoMeta.emoji,
                      style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (descricao.isNotEmpty)
                      Text(
                        descricao,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.grey[400] : Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: estaConcluida
                      ? Colors.green.withValues(alpha: 0.1)
                      : diasRestantes < 0
                          ? Colors.red.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  estaConcluida
                      ? 'Concluída'
                      : diasRestantes < 0
                          ? 'Atrasada'
                          : 'Em andamento',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: estaConcluida
                        ? Colors.green
                        : diasRestantes < 0
                            ? Colors.red
                            : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${tipoMeta.nome} - Até ${DateFormat('dd/MM/yy').format(dataFim)}',
            style: TextStyle(
              fontSize: 9,
              color: isDark ? Colors.grey[400] : Colors.grey[500],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                Formatador.moeda(valorAtual),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                'de ${Formatador.moeda(valorObjetivo)}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[400] : Colors.grey[500],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (progresso.clamp(0.0, 1.0)).toDouble(),
              backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                estaConcluida ? Colors.green : tipoMeta.cor,
              ),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${percentual.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: tipoMeta.cor,
                ),
              ),
              Row(
                children: [
                  if (!estaConcluida)
                    _buildActionButton(
                      icon: Icons.add_rounded,
                      label: 'Depositar',
                      onTap: () => _adicionarDeposito(meta),
                      color: tipoMeta.cor,
                      isDark: isDark,
                    ),
                  const SizedBox(width: 6),
                  _buildActionButton(
                    icon: Icons.edit_outlined,
                    label: '',
                    onTap: () => _editarMeta(meta),
                    color: isDark
                        ? const Color(0xB3FFFFFF)
                        : const Color(0x99000000),
                    isDark: isDark,
                    small: true,
                  ),
                  const SizedBox(width: 4),
                  _buildActionButton(
                    icon: Icons.delete_outline,
                    label: '',
                    onTap: () => _excluirMeta(meta['id'] as int, titulo),
                    color: Colors.red[300]!,
                    isDark: isDark,
                    small: true,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    required bool isDark,
    bool small = false,
  }) {
    if (small) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        elevation: 0,
        minimumSize: Size.zero,
      ),
    );
  }
}
