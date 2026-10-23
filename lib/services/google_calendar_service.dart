import '../models/compromisso.dart';
import 'compromisso_service.dart';
import 'configuracoes_service.dart';
import 'google_calendar_api.dart';

enum GoogleCalendarSyncStatus { created, updated, removed, skipped }

class GoogleCalendarSyncResult {
  final GoogleCalendarSyncStatus status;
  final String? eventId;

  const GoogleCalendarSyncResult(this.status, {this.eventId});
}

class GoogleCalendarService {
  final GoogleCalendarApi api;
  final CompromissoService compromissoService;
  final ConfiguracoesService configuracoes;

  GoogleCalendarService({
    required this.api,
    required this.compromissoService,
    required this.configuracoes,
  });

  Future<GoogleCalendarAccount?> currentAccount() => api.currentAccount();

  Future<GoogleCalendarAccount> connect() async {
    final account = await api.connect();
    await configuracoes.setGoogleCalendarAtivo(true);
    if (configuracoes.googleCalendarId.isEmpty) {
      await configuracoes.setGoogleCalendarId('primary');
    }
    return account;
  }

  Future<void> disconnect() async {
    await api.disconnect();
    await configuracoes.setGoogleCalendarAtivo(false);
    await configuracoes.setGoogleCalendarUltimoSync(null);
  }

  Future<List<GoogleCalendarInfo>> listCalendars() => api.listCalendars();

  Future<void> setCalendar(String calendarId) async {
    await configuracoes.setGoogleCalendarId(calendarId);
  }

  Future<GoogleCalendarSyncResult> syncCompromisso(
    Compromisso compromisso, {
    bool force = false,
  }) async {
    if (!force &&
        (!configuracoes.googleCalendarAtivo ||
            !configuracoes.googleCalendarAutoSync)) {
      return const GoogleCalendarSyncResult(GoogleCalendarSyncStatus.skipped);
    }

    if (!configuracoes.googleCalendarAtivo) {
      throw const GoogleCalendarAuthRequiredException();
    }

    if (compromisso.isCancelado) {
      await removeEvento(compromisso);
      return const GoogleCalendarSyncResult(GoogleCalendarSyncStatus.removed);
    }

    final calendarId = compromisso.googleCalendarId.isNotEmpty
        ? compromisso.googleCalendarId
        : configuracoes.googleCalendarId;
    final data = _toEventData(compromisso);

    if (compromisso.googleEventId.isEmpty) {
      final eventId = await api.createEvent(calendarId, data);
      await _salvarMetadados(compromisso, eventId, calendarId);
      return GoogleCalendarSyncResult(
        GoogleCalendarSyncStatus.created,
        eventId: eventId,
      );
    }

    try {
      await api.updateEvent(calendarId, compromisso.googleEventId, data);
      await _salvarMetadados(
        compromisso,
        compromisso.googleEventId,
        calendarId,
      );
      return GoogleCalendarSyncResult(
        GoogleCalendarSyncStatus.updated,
        eventId: compromisso.googleEventId,
      );
    } on GoogleCalendarHttpException catch (e) {
      if (e.status != 404 && e.status != 410) rethrow;
      final eventId = await api.createEvent(calendarId, data);
      await _salvarMetadados(compromisso, eventId, calendarId);
      return GoogleCalendarSyncResult(
        GoogleCalendarSyncStatus.created,
        eventId: eventId,
      );
    }
  }

  Future<void> removeEvento(Compromisso compromisso) async {
    final eventId = compromisso.googleEventId;
    if (eventId.isEmpty) return;
    if (!configuracoes.googleCalendarAtivo) return;

    final calendarId = compromisso.googleCalendarId.isNotEmpty
        ? compromisso.googleCalendarId
        : configuracoes.googleCalendarId;

    try {
      await api.deleteEvent(calendarId, eventId);
    } on GoogleCalendarHttpException catch (e) {
      if (e.status != 404 && e.status != 410) rethrow;
    }

    compromisso.googleEventId = '';
    compromisso.googleSyncedAt = DateTime.now();
    await compromissoService.atualizarGoogleSync(
      compromisso,
      limparEvento: true,
    );
  }

  GoogleCalendarEventData _toEventData(Compromisso compromisso) {
    final summary = compromisso.ehEventoGeral
        ? (compromisso.titulo.trim().isEmpty
              ? 'Evento geral'
              : compromisso.titulo.trim())
        : 'Sessão';
    final sala = compromisso.sala.trim();

    return GoogleCalendarEventData(
      summary: summary,
      location: sala.isEmpty ? null : sala,
      start: compromisso.dataHoraInicio,
      end: compromisso.dataHoraFim,
      privateProperties: {'mentall_compromisso_id': compromisso.id},
    );
  }

  Future<void> _salvarMetadados(
    Compromisso compromisso,
    String eventId,
    String calendarId,
  ) async {
    final agora = DateTime.now();
    compromisso.googleEventId = eventId;
    compromisso.googleCalendarId = calendarId;
    compromisso.googleSyncedAt = agora;
    await compromissoService.atualizarGoogleSync(
      compromisso,
      eventId: eventId,
      calendarId: calendarId,
    );
    await configuracoes.setGoogleCalendarUltimoSync(agora);
  }
}
