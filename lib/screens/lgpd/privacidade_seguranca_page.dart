import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/service_providers.dart';
import '../../services/lgpd/pdf_arquitetura_lgpd_service.dart';
import '../../utils/mentall_colors.dart';
import '../login_page.dart';
import 'politica_privacidade_page.dart';
import 'termos_uso_page.dart';

final _pinRevisaoProvider = StateProvider<int>((ref) => 0);

class PrivacidadeSegurancaPage extends ConsumerWidget {
  const PrivacidadeSegurancaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(_pinRevisaoProvider);
    final authService = ref.read(authServiceProvider);

    return Scaffold(
      backgroundColor: context.corFundo,
      appBar: AppBar(
        title: const Text('Privacidade e Segurança'),
        backgroundColor: context.corPrimaria,
        foregroundColor: context.corOnPrimaria,
        actions: [
          IconButton(
            tooltip: 'Exportar PDF da Arquitetura LGPD',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () async {
              try {
                await PdfArquiteturaLgpdService().exportar();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Erro ao gerar PDF. Tente novamente.')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _secao(
            context,
            titulo: 'Segurança',
            children: [
              SwitchListTile(
                    title: const Text('Bloqueio por PIN'),
                subtitle: Text(
                  authService.requerPin
                      ? 'PIN configurado. O app solicita PIN ao abrir.'
                      : 'Configure um PIN para proteger seus dados clínicos.',
                ),
                value: authService.requerPin,
                activeThumbColor: context.corPrimaria,
                onChanged: (value) {
                  if (value) {
                    _mostrarDialogConfigurarPin(context, ref);
                  } else {
                    _mostrarDialogRemoverPin(context, ref, authService);
                  }
                },
              ),
              const Divider(indent: 16),
              ListTile(
                leading: const Icon(Icons.lock_outlined),
                title: const Text('Bloquear agora'),
                subtitle: const Text('Bloqueia o app e exige PIN para acessar.'),
                onTap: () async {
                  await authService.bloquear();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (route) => false,
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _secao(
            context,
            titulo: 'Áudio do Relato',
            children: [
              ListTile(
                leading: Icon(Icons.mic_outlined, color: context.corPrimaria),
                title: const Text('Finalidade do áudio'),
                subtitle: Text(
                  'O áudio no MentAll foi projetado para registrar um relato '
                  'clínico breve feito pelo profissional após o atendimento. '
                  'O limite máximo é de 5 minutos por registro. Esse áudio '
                  'pode apoiar a transcrição e a documentação clínica, '
                  'sempre com revisão do profissional.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _secao(
            context,
            titulo: 'IA e Privacidade',
            children: [
              ListTile(
                leading: Icon(Icons.auto_awesome_outlined, color: context.corPrimaria),
                title: const Text('Apoio documental'),
                subtitle: Text(
                  'A IA do MentAll atua apenas como apoio documental. '
                  'Todo conteúdo gerado deve ser revisado e validado '
                  'pelo profissional antes de integrar o prontuário. '
                  'A IA não fornece diagnóstico nem substitui o julgamento clínico.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _secao(
            context,
            titulo: 'Dados e Retenção',
            children: [
              ListTile(
                leading: Icon(Icons.archive_outlined, color: context.corPrimaria),
                title: const Text('Arquivamento em vez de exclusão'),
                subtitle: const Text(
                  'O MentAll mantém a regra de arquivar em vez de excluir. '
                  'Pessoas atendidas e sessões arquivadas continuam preservadas '
                  'no prontuário, podendo ser restauradas a qualquer momento.',
                ),
              ),
              const Divider(indent: 16),
              ListTile(
                leading: Icon(Icons.folder_outlined, color: context.corPrimaria),
                title: const Text('Exportação de dados'),
                subtitle: const Text(
                  'Você pode exportar sessões, históricos e o prontuário completo '
                  'em PDF. Os arquivos exportados contêm dados clínicos sensíveis '
                  'e devem ser armazenados com segurança pelo profissional.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _secao(
            context,
            titulo: 'Auditoria',
            children: [
              ListTile(
                leading: Icon(Icons.history_outlined, color: context.corPrimaria),
                title: const Text('Registro de eventos'),
                subtitle: const Text(
                  'O MentAll registra eventos relevantes para fins de auditoria, '
                  'como criação de registros, alterações clínicas, uso de IA, '
                  'e exportações. Esses registros não contêm dados clínicos.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _mostrarAuditoria(context);
                },
              ),
            ],
          ),
          _secao(
            context,
            titulo: 'Documentos Legais',
            children: [
              ListTile(
                leading: Icon(Icons.description_outlined, color: context.corPrimaria),
                title: const Text('Termos de Uso'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TermosUsoPage()),
                  );
                },
              ),
              const Divider(indent: 16),
              ListTile(
                leading: Icon(Icons.privacy_tip_outlined, color: context.corPrimaria),
                title: const Text('Política de Privacidade'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PoliticaPrivacidadePage()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _secao(BuildContext context,
      {required String titulo, required List<Widget> children}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                titulo,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.corPrimaria,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  void _mostrarDialogConfigurarPin(BuildContext context, WidgetRef ref) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configurar PIN'),
        content: TextField(
          controller: pinController,
          obscureText: true,
          maxLength: 16,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Novo PIN (mínimo 4 caracteres)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final pin = pinController.text.trim();
              if (pin.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('O PIN deve ter no mínimo 4 caracteres.'),
                  ),
                );
                return;
              }
              try {
                await ref.read(authServiceProvider).configurarPin(pin);
                ref.read(_pinRevisaoProvider.notifier).update((v) => v + 1);
                if (ctx.mounted) Navigator.pop(ctx);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PIN configurado com sucesso.'),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Não foi possível configurar o PIN: $e'),
                  ),
                );
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ).then((_) => pinController.dispose());
  }

  void _mostrarDialogRemoverPin(
    BuildContext context,
    WidgetRef ref,
    dynamic authService,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover PIN'),
        content: const Text(
          'Ao remover o PIN, seus dados clínicos ficarão armazenados sem '
          'criptografia local. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              await authService.removerPin();
              ref.read(_pinRevisaoProvider.notifier).update((v) => v + 1);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Remover PIN'),
          ),
        ],
      ),
    );
  }

  void _mostrarAuditoria(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final container = ProviderScope.containerOf(context);
        final auditoriaService = container.read(auditoriaServiceProvider);
        final registros = auditoriaService.listar(limite: 50);

        return AlertDialog(
          title: const Text('Registros de Auditoria'),
          content: SizedBox(
            width: double.maxFinite,
            child: registros.isEmpty
                ? const Text('Nenhum registro de auditoria encontrado.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: registros.length,
                    itemBuilder: (_, i) {
                      final r = registros[i];
                      return ListTile(
                        dense: true,
                        title: Text(
                          r.tipoEvento,
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          r.descricao,
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Text(
                          '${r.dataHora.day.toString().padLeft(2, '0')}/'
                          '${r.dataHora.month.toString().padLeft(2, '0')} '
                          '${r.dataHora.hour.toString().padLeft(2, '0')}:'
                          '${r.dataHora.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }
}
