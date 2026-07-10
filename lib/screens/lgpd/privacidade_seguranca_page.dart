import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/service_providers.dart';
import '../login_page.dart';
import 'politica_privacidade_page.dart';
import 'termos_uso_page.dart';

class PrivacidadeSegurancaPage extends ConsumerWidget {
  const PrivacidadeSegurancaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const Color corPrincipal = Color(0xFF2563EB);
    final authService = ref.read(authServiceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA),
      appBar: AppBar(
        title: const Text('Privacidade e Seguranca'),
        backgroundColor: corPrincipal,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _secao(
            titulo: 'Seguranca',
            children: [
              SwitchListTile(
                title: const Text('Bloqueio por PIN'),
                subtitle: Text(
                  authService.requerPin
                      ? 'PIN configurado. O app solicita PIN ao abrir.'
                      : 'Configure um PIN para proteger seus dados clinicos.',
                ),
                value: authService.requerPin,
                activeThumbColor: corPrincipal,
                onChanged: (value) {
                  if (value) {
                    _mostrarDialogConfigurarPin(context);
                  } else {
                    _mostrarDialogRemoverPin(context, authService);
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
            titulo: 'Audio do Relato',
            children: const [
              ListTile(
                leading: Icon(Icons.mic_outlined, color: Color(0xFF2563EB)),
                title: Text('Finalidade do audio'),
                subtitle: Text(
                  'O audio no MentAll foi projetado para registrar um relato '
                  'clinico breve feito pelo profissional apos o atendimento. '
                  'O limite maximo e de 5 minutos por registro. Esse audio '
                  'pode apoiar a transcricao e a documentacao clinica, '
                  'sempre com revisao do profissional.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _secao(
            titulo: 'IA e Privacidade',
            children: const [
              ListTile(
                leading: Icon(Icons.auto_awesome_outlined, color: Color(0xFF2563EB)),
                title: Text('Apoio documental'),
                subtitle: Text(
                  'A IA do MentAll atua apenas como apoio documental. '
                  'Todo conteudo gerado deve ser revisado e validado '
                  'pelo profissional antes de integrar o prontuario. '
                  'A IA nao fornece diagnostico nem substitui o julgamento clinico.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _secao(
            titulo: 'Dados e Retencao',
            children: [
              ListTile(
                leading: const Icon(Icons.archive_outlined, color: Color(0xFF2563EB)),
                title: const Text('Arquivamento em vez de exclusao'),
                subtitle: const Text(
                  'O MentAll mantem a regra de arquivar em vez de excluir. '
                  'Pessoas atendidas e sessoes arquivadas continuam preservadas '
                  'no prontuario, podendo ser restauradas a qualquer momento.',
                ),
              ),
              const Divider(indent: 16),
              ListTile(
                leading: const Icon(Icons.folder_outlined, color: Color(0xFF2563EB)),
                title: const Text('Exportacao de dados'),
                subtitle: const Text(
                  'Voce pode exportar sessoes, historicos e o prontuario completo '
                  'em PDF. Os arquivos exportados contem dados clinicos sensiveis '
                  'e devem ser armazenados com seguranca pelo profissional.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _secao(
            titulo: 'Auditoria',
            children: [
              ListTile(
                leading: const Icon(Icons.history_outlined, color: Color(0xFF2563EB)),
                title: const Text('Registro de eventos'),
                subtitle: const Text(
                  'O MentAll registra eventos relevantes para fins de auditoria, '
                  'como criacao de registros, alteracoes clinicas, uso de IA, '
                  'e exportacoes. Esses registros nao contem dados clinicos.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _mostrarAuditoria(context);
                },
              ),
            ],
          ),
          _secao(
            titulo: 'Documentos Legais',
            children: [
              ListTile(
                leading: const Icon(Icons.description_outlined, color: Color(0xFF2563EB)),
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
                leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF2563EB)),
                title: const Text('Politica de Privacidade'),
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

  Widget _secao({required String titulo, required List<Widget> children}) {
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  void _mostrarDialogConfigurarPin(BuildContext context) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configurar PIN'),
        content: TextField(
          controller: pinController,
          obscureText: true,
          maxLength: 16,
          decoration: const InputDecoration(
            labelText: 'Novo PIN (minimo 4 caracteres)',
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
              if (pin.length < 4) return;
              final container = ProviderScope.containerOf(context);
              final authService = container.read(authServiceProvider);
              if (authService.requerPin) {
                await authService.encryption.desbloquear('');
              }
              await authService.configurarPin(pin);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    pinController.dispose();
  }

  void _mostrarDialogRemoverPin(BuildContext context, dynamic authService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover PIN'),
        content: const Text(
          'Ao remover o PIN, seus dados clinicos ficarao armazenados sem '
          'criptografia local. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              await authService.bloquear();
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
