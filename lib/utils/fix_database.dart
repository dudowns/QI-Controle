// lib/utils/fix_database.dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  print('🔧 Iniciando correção do banco de dados...');

  final appDir = await getApplicationSupportDirectory();
  final dbPath = join(appDir.path, 'financeiro.db');
  print('📁 Banco de dados em: $dbPath');

  final db = await databaseFactory.openDatabase(dbPath);

  // Lista de tabelas e colunas que devem existir
  final tabelas = {
    'lancamentos': ['created_at', 'updated_at'],
    'proventos': ['created_at', 'updated_at'],
    'investimentos': ['created_at', 'updated_at'],
    'metas': ['created_at', 'updated_at'],
    'renda_fixa': ['created_at', 'updated_at'],
    'depositos_meta': ['created_at'],
  };

  for (var entry in tabelas.entries) {
    final tabela = entry.key;
    final colunas = entry.value;

    print('\n📊 Verificando tabela: $tabela');

    // Verificar colunas existentes
    final tableInfo = await db.rawQuery('PRAGMA table_info($tabela)');
    final colunasExistentes =
        tableInfo.map((col) => col['name'] as String).toList();

    print('   Colunas existentes: ${colunasExistentes.join(', ')}');

    for (var coluna in colunas) {
      if (!colunasExistentes.contains(coluna)) {
        try {
          await db.execute(
              'ALTER TABLE $tabela ADD COLUMN $coluna TEXT DEFAULT CURRENT_TIMESTAMP');
          print('   ✅ Coluna $coluna adicionada em $tabela');
        } catch (e) {
          print('   ❌ Erro ao adicionar $coluna em $tabela: $e');
        }
      } else {
        print('   ⏭️ Coluna $coluna já existe em $tabela');
      }
    }
  }

  await db.close();
  print('\n✅ Correção concluída!');
}
