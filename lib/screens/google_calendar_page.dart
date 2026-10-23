import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/service_providers.dart';
import '../services/google_calendar_api.dart';
import '../services/google_calendar_service.dart';
import '../utils/mentall_colors.dart';
import '../utils/tipografia.dart';

class GoogleCalendarPage extends ConsumerStatefulWidget {
  const GoogleCalendarPage({super.key});

  @override
  ConsumerState<GoogleCalendarPage> createState() => _GoogleCalendarPageState();
}

class _GoogleCalendarPageState extends ConsumerState<GoogleCalendarPage> {
  bool _carregando = true;
  bool _conectando = false;
  bool _sincronizando = false;
  String? _erro;
  GoogleCalendarAccount? _conta;
  List<GoogleCalendarInfo> _calendarios = const [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final service = ref.read(googleCalendarServiceProvider);
    try {
      final conta = await service.currentAccount();
      List<GoogleCalendarInfo> calendarios = const [];
      final ativo = ref.read(configuracoesServiceProvider).googleCalendarAtivo;
      if (conta != null && ativo) {
        calendarios = await service.listCalendars();
      }
      if (!mounted) return;
      setState(() {
        _conta = conta;
        _calendarios = calendarios;
        _carregando = false;
        _erro = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = e.toString();
      });
    }
  }

  Future<void> _conectar() async {
    setState(() {
      _conectando = true;
      _erro = null;
    });
    try {
      final conta = await ref.read(googleCalendarServiceProvider).connect();
      final calendarios = await ref
          .read(googleCalendarServiceProvider)
          .listCalendars();
      if (!mounted) return;
      setState(() {
        _conta = conta;
        _calendarios = calendarios;
        _conectando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Calendar conectado.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _conectando = false;
        _erro = e.toString();
      });
    }
  }

  Future<void> _desconectar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desconectar Google Calendar?'),
        content: const Text(
          'Os eventos já criados no Google não serão apagados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    await ref.read(googleCalendarServiceProvider).disconnect();
    if (!mounted) return;
    setState(() {
      _conta = null;
      _calendarios = const [];
      _erro = null;
    });
  }

  Future<void> _sincronizarAgora() async {
    setState(() {
      _sincronizando = true;
      _erro = null;
    });
    try {
      final service = ref.read(googleCalendarServiceProvider);
      final compromissos = ref.read(compromissoServiceProvider).listarTodos();
      var sincronizados = 0;
      for (final compromisso in compromissos) {
        final resultado = await service.syncCompromisso(
          compromisso,
          force: true,
        );
        if (resultado.status != GoogleCalendarSyncStatus.skipped) {
          sincronizados++;
        }
      }
      if (!mounted) return;
      setState(() => _sincronizando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sincronizados == 0
                ? 'Nenhum compromisso para sincronizar.'
                : '$sincronizados compromisso(s) sincronizado(s).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sincronizando = false;
        _erro = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configuracoesServiceProvider);
    final conectado = _conta != null && config.googleCalendarAtivo;
    final ultimoSync = config.googleCalendarUltimoSync;
    final dataSync = ultimoSync == null
        ? 'Nunca'
        : DateFormat('dd/MM/yyyy HH:mm').format(ultimoSync);

    return Scaffold(
      appBar: AppBar(title: const Text('Google Calendar')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!conectado) ...[
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 64,
                    color: context.corPrimaria,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Leve sua agenda para o Google Calendar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: Tipografia.lg,
                      fontWeight: FontWeight.w700,
                      color: context.corTextoHeading,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'O MentAll cria e atualiza os eventos no calendário '
                    'escolhido. Nenhum nome de paciente é enviado.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.corTextoSecondary,
                      fontSize: Tipografia.base,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _conectando ? null : _conectar,
                    icon: _conectando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(
                      _conectando
                          ? 'Conectando...'
                          : 'Conectar Google Calendar',
                    ),
                  ),
                ] else ...[
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.account_circle_outlined,
                        color: context.corPrimaria,
                      ),
                      title: Text(_conta!.email),
                      subtitle: Text(
                        _conta!.displayName?.isNotEmpty == true
                            ? _conta!.displayName!
                            : 'Conta Google conectada',
                      ),
                      trailing: TextButton(
                        onPressed: _desconectar,
                        child: const Text('Desconectar'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue:
                        _calendarios.any((c) => c.id == config.googleCalendarId)
                        ? config.googleCalendarId
                        : (_calendarios.isNotEmpty
                              ? _calendarios.first.id
                              : null),
                    decoration: const InputDecoration(
                      labelText: 'Calendário',
                      border: OutlineInputBorder(),
                    ),
                    items: _calendarios
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.primary
                                  ? '${c.summary} (principal)'
                                  : c.summary,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (id) async {
                      if (id == null) return;
                      await ref
                          .read(googleCalendarServiceProvider)
                          .setCalendar(id);
                      if (mounted) setState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sincronizar automaticamente'),
                    subtitle: const Text(
                      'Cria/atualiza eventos ao salvar, editar ou excluir.',
                    ),
                    value: config.googleCalendarAutoSync,
                    activeThumbColor: context.corPrimaria,
                    onChanged: (v) async {
                      await config.setGoogleCalendarAutoSync(v);
                      if (mounted) setState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.sync, color: context.corPrimaria),
                    title: const Text('Sincronizar agora'),
                    subtitle: Text('Último sync: $dataSync'),
                    trailing: _sincronizando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _sincronizando ? null : _sincronizarAgora,
                  ),
                ],
                if (_erro != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.corError.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _erro!,
                      style: TextStyle(color: context.corError),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
