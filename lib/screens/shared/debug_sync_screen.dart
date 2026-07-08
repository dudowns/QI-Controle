// lib/screens/debug_sync_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../database/db_helper.dart';

class DebugSyncScreen extends StatefulWidget {
  const DebugSyncScreen({super.key});

  @override
  State<DebugSyncScreen> createState() => _DebugSyncScreenState();
}

class _DebugSyncScreenState extends State<DebugSyncScreen> {
  final DBHelper _dbHelper = DBHelper();
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _localLancamentos = [];
  List<Map<String, dynamic>> _remoteLancamentos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _compararDados();
  }

  Future<void> _compararDados() async {
    setState(() => _loading = true);

    try {
      // Buscar dados LOCAIS
      final local = await _dbHelper.getAllLancamentos();
      _localLancamentos = local;

      // Buscar dados REMOTOS (Supabase)
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final remote = await _supabase
            .from('lancamentos')
            .select()
            .eq('user_id', user.id)
            .order('data', ascending: false);
        _remoteLancamentos = List<Map<String, dynamic>>.from(remote);
      } else {
        _error = 'Usuário não logado';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug: Sync'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _compararDados,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erro: $_error'))
              : Column(
                  children: [
                    // Resumo
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.grey[100],
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildResumoCard(
                            '📱 Local',
                            _localLancamentos.length,
                            Colors.green,
                          ),
                          _buildResumoCard(
                            '☁️ Supabase',
                            _remoteLancamentos.length,
                            Colors.blue,
                          ),
                          _buildResumoCard(
                            '⚠️ Diferença',
                            (_localLancamentos.length -
                                    _remoteLancamentos.length)
                                .abs(),
                            Colors.red,
                          ),
                        ],
                      ),
                    ),

                    // Botões de ação
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.cloud_upload),
                              label: const Text('Forçar Sync Local → Cloud'),
                              onPressed: _syncLocalToCloud,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.cloud_download),
                              label: const Text('Forçar Sync Cloud → Local'),
                              onPressed: _syncCloudToLocal,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Listas comparativas
                    Expanded(
                      child: DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            const TabBar(
                              tabs: [
                                Tab(text: '📱 Local'),
                                Tab(text: '☁️ Supabase'),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _buildLancamentoList(_localLancamentos,
                                      isLocal: true),
                                  _buildLancamentoList(_remoteLancamentos,
                                      isLocal: false),
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
  }

  Widget _buildResumoCard(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 12)),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLancamentoList(List<Map<String, dynamic>> lancamentos,
      {required bool isLocal}) {
    if (lancamentos.isEmpty) {
      return const Center(child: Text('Nenhum lançamento'));
    }

    return ListView.builder(
      itemCount: lancamentos.length,
      itemBuilder: (context, index) {
        final l = lancamentos[index];
        final hasRemoteId =
            l['remote_id'] != null && l['remote_id'].toString().isNotEmpty;
        final syncStatus = l['sync_status'] ?? 'synced';

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: l['tipo'] == 'receita' ? Colors.green : Colors.red,
            child: Text(
              l['tipo'] == 'receita' ? '+' : '-',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Text(l['descricao'] ?? 'Sem descrição'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('R\$ ${l['valor']} - ${l['categoria']}'),
              if (isLocal) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      hasRemoteId ? Icons.cloud_done : Icons.cloud_off,
                      size: 12,
                      color: hasRemoteId ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasRemoteId ? 'Synced' : 'Pending: $syncStatus',
                      style: TextStyle(
                        fontSize: 10,
                        color: hasRemoteId ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          trailing: Text(l['data']?.toString().split('T')[0] ?? ''),
        );
      },
    );
  }

  Future<void> _syncLocalToCloud() async {
    setState(() => _loading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Usuário não logado');

      final db = await _dbHelper.database;

      // Buscar lançamentos locais sem remote_id
      final pending = await db.query(
        DBHelper.tabelaLancamentos,
        where: '(remote_id IS NULL OR remote_id = ?) AND user_id = ?',
        whereArgs: ['', user.id],
      );

      int synced = 0;
      for (var local in pending) {
        try {
          final response = await _supabase
              .from('lancamentos')
              .insert({
                'descricao': local['descricao'],
                'valor': local['valor'],
                'tipo': local['tipo'],
                'categoria': local['categoria'],
                'data': local['data'].toString().split('T')[0],
                'user_id': user.id,
                'observacao': local['observacao'] ?? '',
              })
              .select()
              .single();

          await db.update(
            DBHelper.tabelaLancamentos,
            {
              'remote_id': response['id'],
              'sync_status': 'synced',
            },
            where: 'id = ?',
            whereArgs: [local['id']],
          );
          synced++;
        } catch (e) {
          debugPrint('Erro ao sincronizar: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $synced lançamentos sincronizados local → cloud'),
            backgroundColor: Colors.green,
          ),
        );
        await _compararDados();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncCloudToLocal() async {
    setState(() => _loading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Usuário não logado');

      final db = await _dbHelper.database;

      // Buscar todos do Supabase
      final remote =
          await _supabase.from('lancamentos').select().eq('user_id', user.id);

      int inserted = 0;
      int updated = 0;

      for (var remoteItem in remote) {
        final existing = await db.query(
          DBHelper.tabelaLancamentos,
          where: 'remote_id = ?',
          whereArgs: [remoteItem['id']],
        );

        if (existing.isEmpty) {
          // Inserir novo
          await db.insert(DBHelper.tabelaLancamentos, {
            'remote_id': remoteItem['id'],
            'user_id': remoteItem['user_id'],
            'descricao': remoteItem['descricao'],
            'valor': remoteItem['valor'],
            'tipo': remoteItem['tipo'],
            'categoria': remoteItem['categoria'],
            'data': remoteItem['data'],
            'observacao': remoteItem['observacao'] ?? '',
            'sync_status': 'synced',
          });
          inserted++;
        } else {
          // Atualizar existente
          await db.update(
            DBHelper.tabelaLancamentos,
            {
              'descricao': remoteItem['descricao'],
              'valor': remoteItem['valor'],
              'tipo': remoteItem['tipo'],
              'categoria': remoteItem['categoria'],
              'data': remoteItem['data'],
              'observacao': remoteItem['observacao'] ?? '',
              'sync_status': 'synced',
            },
            where: 'remote_id = ?',
            whereArgs: [remoteItem['id']],
          );
          updated++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $inserted inseridos, $updated atualizados'),
            backgroundColor: Colors.green,
          ),
        );
        await _compararDados();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
