import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_providers.dart';
import '../services/api_client.dart';
import '../services/configuracoes_service.dart';
import '../utils/mentall_colors.dart';
import 'login_page.dart';

final _pinRevisaoProvider = StateProvider<int>((ref) => 0);

class ConfiguracoesPage extends ConsumerStatefulWidget {
  const ConfiguracoesPage({super.key});

  @override
  ConsumerState<ConfiguracoesPage> createState() => _ConfiguracoesPageState();
}

class _ConfiguracoesPageState extends ConsumerState<ConfiguracoesPage> {
  bool _biometriaDisponivel = false;

  @override
  void initState() {
    super.initState();
    _verificarBiometria();
  }

  Future<void> _verificarBiometria() async {
    final authService = ref.read(authServiceProvider);
    final disponivel = await authService.dispositivoPossuiBiometria;
    if (mounted) {
      setState(() => _biometriaDisponivel = disponivel);
    }
  }

  String _labelMinutos(int minutos) {
    if (minutos < 60) return '$minutos minutos';
    final horas = minutos ~/ 60;
    final resto = minutos % 60;
    final labelHora = horas == 1 ? '1 hora' : '$horas horas';
    if (resto == 0) return labelHora;
    return '${horas}h${resto}min';
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
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
                if (_biometriaDisponivel) ...[
                  const Divider(indent: 16),
                  SwitchListTile(
                    secondary: Icon(Icons.fingerprint, color: context.corPrimaria),
                    title: const Text('Desbloquear com digital / face'),
                    subtitle: Text(
                      config.biometriaAtivada
                          ? 'Biometria ativada para desbloqueio rápido.'
                          : 'Toque para ativar o desbloqueio por biometria.',
                    ),
                    value: config.biometriaAtivada,
                    activeThumbColor: context.corPrimaria,
                    onChanged: (v) => config.setBiometriaAtivada(v),
                  ),
                ],
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
          _secao(
            context,
            titulo: 'Contrato',
            children: [
              ListTile(
                leading: Icon(Icons.description_outlined, color: context.corPrimaria),
                title: const Text('Modelo do Acordo Terap\u00eautico'),
                subtitle: const Text(
                  'Personalize o texto do contrato enviado aos pacientes.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _mostrarDialogContrato(context, ref),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinController,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 12),
              decoration: const InputDecoration(
                labelText: 'PIN de 4 digitos',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Voce podera recuperar o PIN pelo seu email profissional.',
              style: TextStyle(fontSize: 12, color: context.corTextoMuted),
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
              final pin = pinController.text.trim();
              if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('O PIN deve ter exatamente 4 digitos.'),
                  ),
                );
                return;
              }
              try {
                await ref.read(authServiceProvider).configurarPin(pin, email: null);
                _notificarPinAlterado(ref);
                if (ctx.mounted) Navigator.pop(ctx);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN configurado com sucesso.')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nao foi possivel configurar o PIN. Tente novamente.'),
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
              maxLength: 4,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 12),
              decoration: const InputDecoration(
                labelText: 'PIN atual (4 digitos)',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: novoController,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 12),
              decoration: const InputDecoration(
                labelText: 'Novo PIN (4 digitos)',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmarController,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 12),
              decoration: const InputDecoration(
                labelText: 'Confirmar novo PIN',
                border: OutlineInputBorder(),
                counterText: '',
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
              if (!RegExp(r'^\d{4}$').hasMatch(novo)) {
                erro = 'O novo PIN deve ter exatamente 4 digitos.';
              } else if (novo != confirmar) {
                erro = 'A confirmacao nao confere com o novo PIN.';
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
                    content: Text('Nao foi possivel trocar o PIN: $e'),
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
    final userController = TextEditingController(text: ApiClient.username);
    final passController = TextEditingController(text: ApiClient.password);
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
            const SizedBox(height: 12),
            TextField(
              controller: userController,
              decoration: const InputDecoration(
                labelText: 'Usu\u00e1rio',
                hintText: 'admin',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Senha',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Altere apenas se souber o que est\u00e1 fazendo. A transcri\u00e7\u00e3o e a '
                's\u00edntese com IA dependem deste endere\u00e7o.',
                style: TextStyle(fontSize: 12, color: context.corTextoMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              urlController.text = ApiClient.defaultBaseUrl;
              userController.text = '';
              passController.text = '';
            },
            child: const Text('Restaurar padr\u00e3o'),
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
                    content: Text('Informe uma URL v\u00e1lida come\u00e7ando com http.'),
                  ),
                );
                return;
              }
              final username = userController.text.trim();
              final password = passController.text.trim();
              if (username.isNotEmpty || password.isNotEmpty) {
                final possuiPin = ref.read(authServiceProvider).encryption.possuiPinConfigurado;
                if (!possuiPin) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Configure um PIN antes de salvar as credenciais do servidor.'),
                      duration: Duration(seconds: 4),
                    ),
                  );
                  return;
                }
              }
              await ApiClient.setBaseUrl(url);
              if (username.isNotEmpty || password.isNotEmpty) {
                await ApiClient.setCredentials(username, password);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ).then((_) {
      urlController.dispose();
      userController.dispose();
      passController.dispose();
    });
  }

  void _mostrarDialogContrato(BuildContext context, WidgetRef ref) {
    final config = ref.read(configuracoesServiceProvider);
    final controller = TextEditingController(text: config.contratoTemplate);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modelo do Contrato'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 12,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Texto do acordo terap\u00eautico',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.text = ConfiguracoesService.contratoPadrao;
            },
            child: const Text('Restaurar padr\u00e3o'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              await config.setContratoTemplate(controller.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contrato atualizado com sucesso.')),
                );
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }
}
