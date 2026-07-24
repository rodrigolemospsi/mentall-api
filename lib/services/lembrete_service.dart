import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/compromisso.dart';
import 'api_client.dart';
import 'logger.dart';

const _canalLembretesId = 'lembretes_mentall';
const _canalLembretesNome = 'Lembretes de sessao';

class LembreteService {
  static final LembreteService _instance = LembreteService._();
  factory LembreteService() => _instance;
  LembreteService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _inicializado = false;

  Future<void> inicializar() async {
    if (_inicializado) return;

    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      const androidChannel = AndroidNotificationChannel(
        _canalLembretesId,
        _canalLembretesNome,
        description: 'Notificacoes de lembretes de sessoes agendadas',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }

    _inicializado = true;
  }

  Future<void> agendarLembrete({
    required Compromisso compromisso,
    required String nomePaciente,
    required String nomeProfissional,
    required String telefonePaciente,
  }) async {
    if (!_inicializado) await inicializar();
    if (!compromisso.lembreteAtivado) return;

    await _cancelarExistente(compromisso.id);

    final horario = compromisso.horarioLembrete;
    if (horario.isBefore(DateTime.now())) return;

    final mensagem = compromisso.formatarMensagemLembrete(
      nomePaciente,
      nomeProfissional,
    );

    final payload = jsonEncode({
      'compromissoId': compromisso.id,
      'telefone': telefonePaciente,
      'mensagem': mensagem,
      'nomePaciente': nomePaciente,
      'canal': compromisso.canalLembrete,
    });

    final canal = compromisso.canalLembrete == 'whatsapp' ? 'WhatsApp' : 'SMS';

    await _notifications.zonedSchedule(
      compromisso.id.hashCode,
      'Lembrete $canal: $nomePaciente',
      'Sessao ${compromisso.horarioInicioFormatado}'
          ' (em ${compromisso.antecedenciaFormatada})',
      tz.TZDateTime.from(horario, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _canalLembretesId,
          _canalLembretesNome,
          channelDescription:
              'Notificacoes de lembretes de sessoes agendadas',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    _enviarParaBackend(
      compromissoId: compromisso.id,
      telefone: telefonePaciente,
      mensagem: mensagem,
      horario: horario,
      canal: compromisso.canalLembrete,
    );
  }

  static Future<void> _enviarParaBackend({
    required String compromissoId,
    required String telefone,
    required String mensagem,
    required DateTime horario,
    String canal = 'whatsapp',
  }) async {
    try {
      await ApiClient.ensureAuthenticated();
      await http
          .post(
            Uri.parse('${ApiClient.baseUrl}/lembretes'),
            headers: ApiClient.defaultHeaders(),
            body: jsonEncode({
              'compromisso_id': compromissoId,
              'telefone': telefone,
              'mensagem': mensagem,
              'horario_envio': horario.toUtc().toIso8601String(),
              'canal': canal,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  Future<void> cancelarLembrete(String compromissoId) async {
    if (!_inicializado) await inicializar();
    await _cancelarExistente(compromissoId);
    _cancelarNoBackend(compromissoId);
  }

  static Future<void> _cancelarNoBackend(String compromissoId) async {
    try {
      await ApiClient.ensureAuthenticated();
      await http
          .delete(
            Uri.parse('${ApiClient.baseUrl}/lembretes/$compromissoId'),
            headers: ApiClient.defaultHeaders(),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<void> _cancelarExistente(String compromissoId) async {
    await _notifications.cancel(compromissoId.hashCode);
  }

  Future<void> reagendarTodos({
    required List<Compromisso> compromissos,
    required String Function(String pacienteId) nomePorPaciente,
    required String Function(String pacienteId) telefonePorPaciente,
    required String nomeProfissional,
  }) async {
    if (!_inicializado) await inicializar();

    final agora = DateTime.now();

    for (final c in compromissos) {
      if (!c.lembreteAtivado || !c.isAgendado) continue;
      if (c.horarioLembrete.isBefore(agora) && c.dataHoraInicio.isBefore(agora)) {
        continue;
      }

      final nome = nomePorPaciente(c.pacienteId);
      final telefone = telefonePorPaciente(c.pacienteId);

      await agendarLembrete(
        compromisso: c,
        nomePaciente: nome,
        nomeProfissional: nomeProfissional,
        telefonePaciente: telefone,
      );
    }
  }

  static void _onNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      final telefone = data['telefone'] as String? ?? '';
      final mensagem = data['mensagem'] as String? ?? '';
      final canal = data['canal'] as String? ?? 'whatsapp';
      if (telefone.isNotEmpty && mensagem.isNotEmpty) {
        _enviarMensagem(telefone, mensagem, canal: canal);
      }
    } catch (_) {}
  }

  static Future<bool> _enviarMensagem(
    String telefone,
    String mensagem, {
    String canal = 'whatsapp',
  }) async {
    try {
      await ApiClient.ensureAuthenticated();

      final endpoint = canal == 'whatsapp' ? '/enviar-whatsapp' : '/enviar-sms';
      final canalNome = canal == 'whatsapp' ? 'WhatsApp' : 'SMS';

      final response = await http
          .post(
            Uri.parse('${ApiClient.baseUrl}$endpoint'),
            headers: ApiClient.defaultHeaders(),
            body: jsonEncode({
              'telefone': telefone,
              'mensagem': mensagem,
            }),
          )
          .timeout(ApiClient.timeout);

      if (response.statusCode == 200) {
        return true;
      }
      Log.erro(
        'Falha ao enviar $canalNome: ${response.statusCode} ${response.body}',
        contexto: 'LembreteService._enviarMensagem',
      );
      return false;
    } catch (e) {
      Log.erro(e, contexto: 'LembreteService._enviarMensagem');
      return false;
    }
  }
}
