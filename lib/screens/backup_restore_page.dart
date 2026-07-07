import 'dart:async';

import 'package:flutter/material.dart';

import '../services/backup_service.dart';
import 'backup_restore_page_stub.dart'
    if (dart.library.html) 'backup_restore_page_web.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  final BackupService _backupService = BackupService();
  bool _exportando = false;
  bool _importando = false;

  Future<void> _exportar() async {
    setState(() => _exportando = true);

    try {
      final json = _backupService.exportarParaJson();
      final nomeArquivo =
          'mentall_backup_${DateTime.now().millisecondsSinceEpoch}.json';

      baixarJsonWeb(json, nomeArquivo);

      if (!mounted) return;
      _mostrarSnackBar('Backup exportado com sucesso!', Colors.green);
    } catch (e) {
      if (!mounted) return;
      _mostrarSnackBar('Erro ao exportar: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<void> _importar() async {
    try {
      final jsonString = await selecionarArquivoJsonWeb();
      if (jsonString == null) return;

      setState(() => _importando = true);

      final resultado = await _backupService.importarDeJson(jsonString);

      if (!mounted) return;
      _mostrarSnackBar(resultado, Colors.green);
    } catch (e) {
      if (!mounted) return;
      _mostrarSnackBar('Erro ao importar: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _importando = false);
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
                    onPressed: _exportando ? null : _exportar,
                    icon: _exportando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download),
                    label: Text(
                        _exportando ? 'Exportando...' : 'Exportar backup'),
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
                    onPressed: _importando ? null : _importar,
                    icon: _importando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.upload),
                    label: Text(
                        _importando ? 'Importando...' : 'Importar backup'),
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
