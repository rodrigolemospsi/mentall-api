import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_providers.dart';
import 'backup_restore_page_stub.dart'
    if (dart.library.html) 'backup_restore_page_web.dart';

final _exportandoProvider = StateProvider<bool>((ref) => false);
final _importandoProvider = StateProvider<bool>((ref) => false);

class BackupRestorePage extends ConsumerStatefulWidget {
  const BackupRestorePage({super.key});

  @override
  ConsumerState<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends ConsumerState<BackupRestorePage> {
  Future<void> _exportar() async {
    ref.read(_exportandoProvider.notifier).state = true;

    try {
      final json = ref.read(backupServiceProvider).exportarParaJson();
      final nomeArquivo =
          'mentall_backup_${DateTime.now().millisecondsSinceEpoch}.json';

      baixarJsonWeb(json, nomeArquivo);

      if (!mounted) return;
      _mostrarSnackBar('Backup exportado com sucesso!', Colors.green);
    } catch (e) {
      if (!mounted) return;
      _mostrarSnackBar('Erro ao exportar: $e', Colors.red);
    } finally {
      if (mounted) ref.read(_exportandoProvider.notifier).state = false;
    }
  }

  Future<void> _importar() async {
    try {
      final jsonString = await selecionarArquivoJsonWeb();
      if (jsonString == null) return;

      ref.read(_importandoProvider.notifier).state = true;

      final resultado =
          await ref.read(backupServiceProvider).importarDeJson(jsonString);

      if (!mounted) return;
      _mostrarSnackBar(resultado, Colors.green);
    } catch (e) {
      if (!mounted) return;
      _mostrarSnackBar('Erro ao importar: $e', Colors.red);
    } finally {
      if (mounted) ref.read(_importandoProvider.notifier).state = false;
    }
  }

  void _mostrarSnackBar(String mensagem, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: cor),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color corPrincipal = Color(0xFF1F6F78);
    final exportando = ref.watch(_exportandoProvider);
    final importando = ref.watch(_importandoProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA),
      appBar: AppBar(
        title: const Text('Backup e restauração'),
        backgroundColor: corPrincipal,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.download_outlined,
                      size: 40, color: corPrincipal),
                  const SizedBox(height: 12),
                  const Text(
                    'Exportar dados',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Gera um arquivo JSON com todos os pacientes, sessões e configurações do perfil.',
                    style: TextStyle(color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: exportando ? null : _exportar,
                    icon: exportando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download),
                    label: Text(exportando ? 'Exportando...' : 'Exportar backup'),
                    style: FilledButton.styleFrom(
                      backgroundColor: corPrincipal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.upload_outlined,
                      size: 40, color: corPrincipal),
                  const SizedBox(height: 12),
                  const Text(
                    'Importar dados',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Restaura dados de um arquivo JSON. Itens com ID já existente são ignorados (sem sobrescrita).',
                    style: TextStyle(color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: importando ? null : _importar,
                    icon: importando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.upload),
                    label: Text(importando ? 'Importando...' : 'Importar backup'),
                    style: FilledButton.styleFrom(
                      backgroundColor: corPrincipal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: Colors.blue.shade200),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'O backup não inclui arquivos de áudio, apenas metadados e dados textuais. '
                      'Mantenha o arquivo .json em local seguro.',
                      style: TextStyle(color: Colors.black87, height: 1.4),
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
}
