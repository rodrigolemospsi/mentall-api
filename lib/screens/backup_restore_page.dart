import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_providers.dart';
import '../services/backup_storage.dart';
import '../services/backup_service.dart';
import '../services/configuracoes_service.dart';
import '../utils/mentall_colors.dart';
import '../utils/raio.dart';
import '../utils/tipografia.dart';
import 'backup_restore_page_io.dart'
    if (dart.library.html) 'backup_restore_page_web.dart';
import 'exportar_tudo_page.dart';

final _exportandoProvider = StateProvider<bool>((ref) => false);
final _importandoProvider = StateProvider<bool>((ref) => false);

class BackupRestorePage extends ConsumerStatefulWidget {
  const BackupRestorePage({super.key});

  @override
  ConsumerState<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends ConsumerState<BackupRestorePage> {
  Future<bool> _validarAutenticacaoAntesExportar() async {
    final authService = ref.read(authServiceProvider);
    if (authService.desbloqueado) return true;
    if (!authService.requerAutenticacao) return true;

    // Tenta biometria primeiro
    final biometriaOk = await authService.desbloquearComBiometria();
    if (biometriaOk) return true;

    // Fallback: solicita PIN via dialog
    return _solicitarPinDialog();
  }

  Future<bool> _solicitarPinDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Autenticação necessária'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Digite seu PIN para autorizar a exportação do backup:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'PIN',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (result != true) return false;

    final pin = controller.text.trim();
    controller.dispose();
    if (pin.isEmpty) return false;

    final authService = ref.read(authServiceProvider);
    return authService.validarPin(pin);
  }

  Future<void> _exportar() async {
    final autorizado = await _validarAutenticacaoAntesExportar();
    if (!autorizado) {
      if (mounted) {
        _mostrarSnackBar('Autenticação necessária para exportar.', context.corError);
      }
      return;
    }
    if (!mounted) return;

    final portavel = await _escolherModoExportacao();
    if (portavel == null) return; // cancelou

    String? senha;
    if (portavel) {
      senha = await _pedirSenha(
        titulo: 'Backup portátil (com senha)',
        mensagem:
            'Escolha uma senha para este backup. Ela permite restaurar os dados em '
            'QUALQUER aparelho, mesmo depois de reinstalar o app. Guarde-a bem: '
            'sem ela o backup não pode ser aberto.',
        confirmarSenha: true,
      );
      if (senha == null) return;
    }

    ref.read(_exportandoProvider.notifier).state = true;

    try {
      final servico = ref.read(backupServiceProvider);
      final json = portavel
          ? await servico.exportarParaJsonPortavel(senha!)
          : servico.exportarParaJson();
      final prefixo = portavel ? 'mentall_backup_portatil_' : 'mentall_backup_';
      final nomeArquivo = '$prefixo${DateTime.now().millisecondsSinceEpoch}.json';

      await exportarJson(json, nomeArquivo);

      if (!mounted) return;
      _mostrarSnackBar(
        portavel
            ? 'Backup portátil exportado! Restaurável em qualquer aparelho com a senha.'
            : 'Backup exportado com sucesso!',
        context.corSuccess,
      );
    } catch (e) {
      if (!mounted) return;
      _mostrarSnackBar('Não foi possível exportar o backup. Tente novamente.', context.corError);
    } finally {
      if (mounted) ref.read(_exportandoProvider.notifier).state = false;
    }
  }

  Future<void> _importar() async {
    final autorizado = await _validarAutenticacaoAntesExportar();
    if (!autorizado) {
      if (mounted) {
        _mostrarSnackBar('Autenticação necessária para importar.', context.corError);
      }
      return;
    }

    try {
      final jsonString = await selecionarArquivoJson();
      if (jsonString == null) return;

      String? senha;
      if (BackupService.ehBackupComSenha(jsonString)) {
        if (!mounted) return;
        senha = await _pedirSenha(
          titulo: 'Backup protegido por senha',
          mensagem: 'Digite a senha definida quando este backup portátil foi exportado.',
          confirmarSenha: false,
        );
        if (senha == null) return;
      }

      ref.read(_importandoProvider.notifier).state = true;

      final resultado =
          await ref.read(backupServiceProvider).importarDeJson(jsonString, senha: senha);

      if (!mounted) return;
      _mostrarSnackBar(resultado, context.corSuccess);
    } catch (e) {
      if (!mounted) return;
      _mostrarSnackBar('Não foi possível importar o backup. Verifique o arquivo.', context.corError);
    } finally {
      if (mounted) ref.read(_importandoProvider.notifier).state = false;
    }
  }

  /// Diálogo de escolha: backup portátil (com senha) ou só neste aparelho.
  Future<bool?> _escolherModoExportacao() async {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Como exportar o backup?'),
        content: const Text(
          '• Portátil (recomendado): protegido por senha, pode ser restaurado em '
          'qualquer aparelho — use antes de trocar de celular ou reinstalar o app.\n\n'
          '• Só neste aparelho: usa a chave do aparelho atual e só abre nele.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Só neste aparelho'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Portátil (com senha)'),
          ),
        ],
      ),
    );
  }

  /// Pede uma senha (com confirmação opcional) para backup/chave portátil.
  Future<String?> _pedirSenha({
    required String titulo,
    required String mensagem,
    required bool confirmarSenha,
  }) async {
    final senhaController = TextEditingController();
    final confirmacaoController = TextEditingController();
    final erroController = ValueNotifier<String?>(null);

    final resultado = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(titulo),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(mensagem),
              const SizedBox(height: 16),
              TextField(
                controller: senhaController,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Senha (mínimo 8 caracteres)'),
              ),
              if (confirmarSenha) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: confirmacaoController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Repita a senha'),
                ),
              ],
              ValueListenableBuilder<String?>(
                valueListenable: erroController,
                builder: (contexto, erro, _) => erro == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          erro,
                          style: TextStyle(color: contexto.corError),
                        ),
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final senha = senhaController.text;
              if (senha.length < 8) {
                erroController.value = 'Use pelo menos 8 caracteres.';
                return;
              }
              if (confirmarSenha && senha != confirmacaoController.text) {
                erroController.value = 'As senhas não conferem.';
                return;
              }
              Navigator.of(dialogContext).pop(senha);
            },
            child: Text(confirmarSenha ? 'Criar backup' : 'Abrir backup'),
          ),
        ],
      ),
    );

    senhaController.dispose();
    confirmacaoController.dispose();
    erroController.dispose();
    return resultado;
  }

  Future<void> _exportarChaveRecuperacao() async {
    final autorizado = await _validarAutenticacaoAntesExportar();
    if (!autorizado) return;
    if (!mounted) return;
    final senha = await _pedirSenha(
      titulo: 'Exportar chave de recuperação',
      mensagem:
          'A chave de recuperação permite abrir backups ANTIGOS (feitos neste '
          'aparelho) em um aparelho novo. Guarde o arquivo e a senha separados.',
      confirmarSenha: true,
    );
    if (senha == null) return;
    try {
      final chave = await ref.read(backupServiceProvider).exportarChaveRecuperacao(senha);
      if (chave == null) {
        if (!mounted) return;
        _mostrarSnackBar('Não foi possível gerar a chave de recuperação.', context.corError);
        return;
      }
      await exportarJson(
        chave,
        'mentall_chave_recuperacao_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      if (!mounted) return;
      _mostrarSnackBar('Chave de recuperação exportada!', context.corSuccess);
    } catch (_) {
      if (!mounted) return;
      _mostrarSnackBar('Não foi possível gerar a chave de recuperação.', context.corError);
    }
  }

  Future<void> _importarChaveRecuperacao() async {
    final autorizado = await _validarAutenticacaoAntesExportar();
    if (!autorizado) return;
    try {
      final jsonString = await selecionarArquivoJson();
      if (jsonString == null) return;
      if (!mounted) return;
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Importar chave de recuperação?'),
          content: const Text(
            'A chave deste aparelho será SUBSTITUÍDA pela chave do arquivo. '
            'Faça isso apenas em aparelho novo ou para recuperar backups antigos. '
            'Dados já gravados neste aparelho com a chave atual podem ficar ilegíveis.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Substituir chave'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
      if (!mounted) return;
      final senha = await _pedirSenha(
        titulo: 'Senha da chave de recuperação',
        mensagem: 'Digite a senha definida quando a chave foi exportada.',
        confirmarSenha: false,
      );
      if (senha == null) return;
      final ok = await ref
          .read(backupServiceProvider)
          .importarChaveRecuperacao(jsonString, senha);
      if (!mounted) return;
      _mostrarSnackBar(
        ok
            ? 'Chave importada! Agora você pode importar backups antigos deste aparelho.'
            : 'Senha incorreta ou arquivo de chave inválido.',
        ok ? context.corSuccess : context.corError,
      );
    } catch (_) {
      if (!mounted) return;
      _mostrarSnackBar('Não foi possível importar a chave de recuperação.', context.corError);
    }
  }

  void _mostrarSnackBar(String mensagem, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: cor),
    );
  }

  String _labelFrequenciaBackup(String f) {
    switch (f) {
      case 'diario':
        return 'Diário, automaticamente (a cada 24h)';
      case 'semanal':
        return 'Semanal (a cada 7 dias)';
      case 'mensal':
        return 'Mensal (a cada 30 dias)';
      case 'off':
      default:
        return 'Desativado';
    }
  }

  String _abreviaPasta(String caminho) {
    if (caminho.length <= 34) return caminho;
    return '…${caminho.substring(caminho.length - 33)}';
  }

  String _formatarDataHora(DateTime d) {
    final dia = d.day.toString().padLeft(2, '0');
    final mes = d.month.toString().padLeft(2, '0');
    final hora = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${d.year} às $hora:$min';
  }

  bool _backupAtrasado(ConfiguracoesService config) {
    final f = config.backupFrequencia;
    if (f == 'off') return false;
    final ultimo = config.ultimoBackupEm;
    if (ultimo == null) return true;
    final dias = switch (f) {
      'diario' => 1,
      'semanal' => 7,
      _ => 30,
    };
    return DateTime.now().difference(ultimo).inDays >= dias;
  }

  Future<void> _escolherPasta(ConfiguracoesService config) async {
    final pasta = await escolherPastaBackup();
    if (pasta != null) {
      await config.setBackupLocal(pasta);
    }
  }

  Future<void> _fazerBackupAgora() async {
    final caminho =
        await ref.read(backupAgendamentoServiceProvider).executar();
    if (!mounted) return;
    _mostrarSnackBar(
      caminho != null
          ? 'Backup salvo em: ${_abreviaPasta(caminho)}'
          : 'Não foi possível salvar o backup. Tente novamente.',
      caminho != null ? context.corSuccess : context.corError,
    );
  }

  Widget _cardBackupAutomatico(
    BuildContext context,
    ConfiguracoesService config,
  ) {
    final atrasado = _backupAtrasado(config);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raio.xxl),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  Icon(Icons.schedule_outlined, color: context.corPrimaria),
                  const SizedBox(width: 10),
                  const Text(
                    'Backup automático',
                    style: TextStyle(
                      fontSize: Tipografia.lg,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.update_outlined, color: context.corPrimaria),
              title: const Text('Frequência'),
              subtitle: Text(_labelFrequenciaBackup(config.backupFrequencia)),
              trailing: DropdownButton<String>(
                value: config.backupFrequencia,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'off', child: Text('Desativado')),
                  DropdownMenuItem(value: 'diario', child: Text('Diário')),
                  DropdownMenuItem(value: 'semanal', child: Text('Semanal')),
                  DropdownMenuItem(value: 'mensal', child: Text('Mensal')),
                ],
                onChanged: (v) {
                  if (v != null) config.setBackupFrequencia(v);
                },
              ),
            ),
            const Divider(height: 1, indent: 16),
            ListTile(
              leading: Icon(Icons.folder_outlined, color: context.corPrimaria),
              title: const Text('Local do backup'),
              subtitle: Text(
                config.backupLocal.isEmpty
                    ? 'Pasta padrão do app'
                    : _abreviaPasta(config.backupLocal),
              ),
              trailing: TextButton(
                onPressed: () => _escolherPasta(config),
                child: const Text('Escolher'),
              ),
            ),
            const Divider(height: 1, indent: 16),
            ListTile(
              leading: Icon(
                atrasado ? Icons.warning_amber : Icons.verified_user_outlined,
                color: atrasado ? context.corWarning : context.corSuccess,
              ),
              title: const Text('Último backup'),
              subtitle: Text(
                config.ultimoBackupEm == null
                    ? 'Nenhum backup feito ainda'
                    : _formatarDataHora(config.ultimoBackupEm!),
              ),
              trailing: TextButton(
                onPressed: _fazerBackupAgora,
                child: const Text('Fazer agora'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardChaveRecuperacao(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raio.xxl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.key_outlined, size: 40, color: context.corPrimaria),
            const SizedBox(height: 12),
            const Text(
              'Chave de recuperação',
              style: TextStyle(fontSize: Tipografia.lg, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Exporte a chave deste aparelho protegida por senha para conseguir abrir '
              'backups antigos (formato anterior) em um aparelho novo.',
              style: TextStyle(color: context.corTextoSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _exportarChaveRecuperacao,
                  icon: const Icon(Icons.vpn_key_outlined),
                  label: const Text('Exportar chave'),
                ),
                OutlinedButton.icon(
                  onPressed: _importarChaveRecuperacao,
                  icon: const Icon(Icons.key),
                  label: const Text('Importar chave'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(configuracoesRevisaoProvider);
    final config = ref.read(configuracoesServiceProvider);
    final exportando = ref.watch(_exportandoProvider);
    final importando = ref.watch(_importandoProvider);

    return Scaffold(
      backgroundColor: context.corFundo,
      appBar: AppBar(
        title: const Text('Backup e dados'),
        backgroundColor: context.corPrimaria,
        foregroundColor: context.corOnPrimaria,
        actions: [
          IconButton(
            tooltip: 'Exportar tudo em PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExportarTudoPage()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Raio.xxl),
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
                    style: TextStyle(fontSize: Tipografia.lg, fontWeight: FontWeight.bold),
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
              borderRadius: BorderRadius.circular(Raio.xxl),
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
                    style: TextStyle(fontSize: Tipografia.lg, fontWeight: FontWeight.bold),
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
          const SizedBox(height: 16),
          _cardBackupAutomatico(context, config),
          const SizedBox(height: 16),
          _cardChaveRecuperacao(context),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            color: context.corContainerPrimario,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Raio.xxl),
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
                      'Use o backup PORTÁTIL (com senha) antes de trocar de aparelho ou reinstalar o app: '
                      'o backup padrão só abre neste aparelho. Mantenha o arquivo .json em local seguro.',
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
