import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_providers.dart';
import '../utils/mentall_colors.dart';
import 'backup_restore_page_io.dart'
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

      await exportarJson(json, nomeArquivo);

      if (!mounted) return;
      _mostrarSnackBar('Backup exportado com sucesso!', context.corSuccess);
    } catch (e) {
      if (!mounted) return;
      _mostrarSnackBar('Erro ao exportar: $e', context.corError);
    } finally {
      if (mounted) ref.read(_exportandoProvider.notifier).state = false;
    }
  }

  Future<void> _importar() async {
    try {
      final jsonString = await selecionarArquivoJson();
      if (jsonString == null) return;

      ref.read(_importandoProvider.notifier).state = true;

      final resultado =
          await ref.read(backupServiceProvider).importarDeJson(jsonString);

      if (!mounted) return;
      _mostrarSnackBar(resultado, context.corSuccess);
    } catch (e) {
      if (!mounted) return;
      _mostrarSnackBar('Erro ao importar: $e', context.corError);
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
    final exportando = ref.watch(_exportandoProvider);
    final importando = ref.watch(_importandoProvider);

    return Scaffold(
      backgroundColor: context.corFundo,
      appBar: AppBar(
        title: const Text('Backup e restauração'),
        backgroundColor: context.corPrimaria,
        foregroundColor: context.corOnPrimaria,
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
                  Icon(Icons.download_outlined,
                      size: 40, color: context.corPrimaria),
                  const SizedBox(height: 12),
                  const Text(
                    'Exportar dados',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gera um arquivo JSON com todos os pacientes, sessões e configurações do perfil.',
                    style: TextStyle(color: context.corTextoSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: exportando ? null : _exportar,
                    icon: exportando
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.corOnPrimaria,
                            ),
                          )
                        : const Icon(Icons.download),
                    label: Text(exportando ? 'Exportando...' : 'Exportar backup'),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.corPrimaria,
                      foregroundColor: context.corOnPrimaria,
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
                  Icon(Icons.upload_outlined,
                      size: 40, color: context.corPrimaria),
                  const SizedBox(height: 12),
                  const Text(
                    'Importar dados',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Restaura dados de um arquivo JSON. Itens com ID já existente são sobrescritos com o conteúdo do backup.',
                    style: TextStyle(color: context.corTextoSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: importando ? null : _importar,
                    icon: importando
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.corOnPrimaria,
                            ),
                          )
                        : const Icon(Icons.upload),
                    label: Text(importando ? 'Importando...' : 'Importar backup'),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.corPrimaria,
                      foregroundColor: context.corOnPrimaria,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            color: context.corContainerPrimario,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: context.corPrimaria.withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: context.corPrimaria),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'O backup não inclui arquivos de áudio, apenas metadados e dados textuais. '
                      'Mantenha o arquivo .json em local seguro.',
                      style: TextStyle(color: context.corTextoBody, height: 1.4),
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
