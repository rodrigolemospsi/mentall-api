import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_providers.dart';
import '../services/api_client.dart';
import '../services/configuracoes_service.dart';
import '../utils/mentall_colors.dart';
import 'login_page.dart';

final _pinRevisaoProvider = StateProvider<int>((ref) => 0);

class ConfiguracoesPage extends ConsumerWidget {
  const ConfiguracoesPage({super.key});

  String _labelMinutos(int minutos) {
    if (minutos < 60) return '$minutos minutos';
    final horas = minutos ~/ 60;
    final resto = minutos % 60;
    final labelHora = horas == 1 ? '1 hora' : '$horas horas';
    if (resto == 0) return labelHora;
    return '${horas}h${resto}min';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(configuracoesRevisaoProvider);
    ref.watch(_pinRevisaoProvider);

    final config = ref.read(configuracoesServiceProvider);
    final authService = ref.read(authServiceProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _secao(
          context,
            titulo: 'Aparência',
            children: [
              SwitchListTile(
                title: const Text('Tema escuro'),
                subtitle: Text(
                  config.temaEscuro
                      ? 'Tema escuro ativado.'
                      : 'Toque para usar o tema escuro.',
                ),
                value: config.temaEscuro,
                activeThumbColor: context.corPrimaria,
                secondary: Icon(
                  config.temaEscuro ? Icons.dark_mode : Icons.light_mode,
                  color: context.corPrimaria,
                ),
                onChanged: (value) {
                  ref
                      .read(configuracoesServiceProvider)
                      .setTemaEscuro(value);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                    _mostrarDialogRemoverPin(context, ref);
                  }
                },
              ),
              if (authService.requerPin) ...[
                const Divider(indent: 16),
                ListTile(
                  leading: Icon(Icons.password_outlined, color: context.corPrimaria),
                  title: const Text('Trocar PIN'),
                  subtitle: const Text(
                    'Altera o PIN mantendo seus dados protegidos.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _mostrarDialogTrocarPin(context, ref),
                ),
                const Divider(indent: 16),
                ListTile(
                  leading: Icon(Icons.lock_outlined, color: context.corPrimaria),
                  title: const Text('Bloquear agora'),
                  subtitle:
                      const Text('Bloqueia o app e exige PIN para acessar.'),
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
            ],
          ),
          const SizedBox(height: 16),
          _secao(
          context,
            titulo: 'Agenda e lembretes',
            children: [
              ListTile(
                leading: Icon(Icons.timelapse_outlined, color: context.corPrimaria),
                title: const Text('Duração padrão da sessão'),
                subtitle: Text(
                  'Novos compromissos terminam ${_labelMinutos(config.duracaoPadraoSessaoMinutos)} após o início.',
                ),
                trailing: DropdownButton<int>(
                  value: config.duracaoPadraoSessaoMinutos,
                  underline: const SizedBox.shrink(),
                  items: ConfiguracoesService.opcoesDuracaoMinutos
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(_labelMinutos(m)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) config.setDuracaoPadraoSessaoMinutos(v);
                  },
                ),
              ),
              const Divider(indent: 16),
              SwitchListTile(
                title: const Text('Lembrete ativado por padrão'),
                subtitle: const Text(
                  'Novos compromissos já nascem com lembrete via SMS ligado.',
                ),
                value: config.lembretePadraoAtivado,
                activeThumbColor: context.corPrimaria,
                onChanged: (v) => config.setLembretePadraoAtivado(v),
              ),
              const Divider(indent: 16),
              ListTile(
                leading: Icon(Icons.timer_outlined, color: context.corPrimaria),
                title: const Text('Antecedência padrão do lembrete'),
                subtitle: Text(
                  'Lembretes enviados ${_labelMinutos(config.antecedenciaPadraoMinutos)} antes da sessão.',
                ),
                trailing: DropdownButton<int>(
                  value: config.antecedenciaPadraoMinutos,
                  underline: const SizedBox.shrink(),
                  items: ConfiguracoesService.opcoesAntecedenciaMinutos
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(_labelMinutos(m)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) config.setAntecedenciaPadraoMinutos(v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _secao(
          context,
            titulo: 'Inteligência Artificial',
            children: [
              SwitchListTile(
                title: const Text('Sugerir artigos científicos'),
                subtitle: const Text(
                  'Ao gerar a síntese clínica, incluir indicações de leitura '
                  'complementar baseadas na sessão.',
                ),
                value: config.sugerirArtigos,
                activeThumbColor: context.corPrimaria,
                onChanged: (v) => config.setSugerirArtigos(v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _secao(
          context,
            titulo: 'Avançado',
            children: [
              ListTile(
                leading: Icon(Icons.dns_outlined, color: context.corPrimaria),
                title: const Text('Servidor'),
                subtitle: Text(
                  ApiClient.baseUrlExibicao,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _mostrarDialogServidor(context, ref),
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

  void _notificarPinAlterado(WidgetRef ref) {
    ref.read(_pinRevisaoProvider.notifier).update((v) => v + 1);
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
                final frase = await ref.read(authServiceProvider).configurarPinComFraseRecuperacao(pin);
                _notificarPinAlterado(ref);
                if (ctx.mounted) Navigator.pop(ctx);
                if (!context.mounted) return;
                _mostrarFraseRecuperacao(context, frase);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Não foi possível configurar o PIN. Tente novamente.'),
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

  void _mostrarDialogTrocarPin(BuildContext context, WidgetRef ref) {
    final atualController = TextEditingController();
    final novoController = TextEditingController();
    final confirmarController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trocar PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: atualController,
              obscureText: true,
              maxLength: 16,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'PIN atual',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: novoController,
              obscureText: true,
              maxLength: 16,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Novo PIN (mínimo 4 caracteres)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmarController,
              obscureText: true,
              maxLength: 16,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Confirmar novo PIN',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final atual = atualController.text.trim();
              final novo = novoController.text.trim();
              final confirmar = confirmarController.text.trim();

              String? erro;
              if (novo.length < 4) {
                erro = 'O novo PIN deve ter no mínimo 4 caracteres.';
              } else if (novo != confirmar) {
                erro = 'A confirmação não confere com o novo PIN.';
              }

              if (erro != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(erro)),
                );
                return;
              }

              try {
                final sucesso =
                    await ref.read(authServiceProvider).trocarPin(atual, novo);
                _notificarPinAlterado(ref);

                if (!ctx.mounted) return;
                if (sucesso) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN alterado com sucesso.')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN atual incorreto.')),
                  );
                }
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Não foi possível trocar o PIN: $e'),
                  ),
                );
              }
            },
            child: const Text('Trocar'),
          ),
        ],
      ),
    ).then((_) {
      atualController.dispose();
      novoController.dispose();
      confirmarController.dispose();
    });
  }

  void _mostrarDialogRemoverPin(BuildContext context, WidgetRef ref) {
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
              await ref.read(authServiceProvider).removerPin();
              _notificarPinAlterado(ref);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: context.corDanger,
            ),
            child: const Text('Remover PIN'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogServidor(BuildContext context, WidgetRef ref) {
    final urlController = TextEditingController(text: ApiClient.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Servidor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL do servidor',
                hintText: 'https://mentall-api.onrender.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Altere apenas se souber o que está fazendo. A transcrição e a '
                'síntese com IA dependem deste endereço.',
                style: TextStyle(fontSize: 12, color: context.corTextoMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              urlController.text = ApiClient.defaultBaseUrl;
            },
            child: const Text('Restaurar padrão'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final url = urlController.text.trim();
              if (url.isEmpty || !url.startsWith('http')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Informe uma URL válida começando com http.'),
                  ),
                );
                return;
              }
              await ApiClient.setBaseUrl(url);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ).then((_) => urlController.dispose());
  }

  void _mostrarFraseRecuperacao(BuildContext context, String frase) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Frase de recuperação'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Guarde esta frase em local seguro. Sem ela, seus dados serão permanentemente inacessíveis se você esquecer o PIN.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                frase,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Copie ou anote estas 12 palavras na ordem exata.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('PIN configurado com sucesso. Guarde a frase de recuperação.'),
                ),
              );
            },
            child: const Text('Eu anotei. OK'),
          ),
        ],
      ),
    );
  }
}
