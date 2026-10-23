import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/compromisso.dart';
import 'package:prontuario_tcc/services/compromisso_service.dart';
import 'package:prontuario_tcc/services/configuracoes_service.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';
import 'package:prontuario_tcc/services/google_calendar_api.dart';
import 'package:prontuario_tcc/services/google_calendar_service.dart';

class _FakeGoogleCalendarApi implements GoogleCalendarApi {
  bool connected = true;
  bool failUpdate404 = false;
  bool failDelete404 = false;
  final List<({String calendarId, GoogleCalendarEventData data})> created = [];
  final List<
    ({String calendarId, String eventId, GoogleCalendarEventData data})
  >
  updated = [];
  final List<({String calendarId, String eventId})> deleted = [];

  @override
  Future<GoogleCalendarAccount?> currentAccount() async {
    return connected
        ? const GoogleCalendarAccount(email: 'teste@example.com')
        : null;
  }

  @override
  Future<GoogleCalendarAccount> connect() async {
    connected = true;
    return const GoogleCalendarAccount(email: 'teste@example.com');
  }

  @override
  Future<void> disconnect() async {
    connected = false;
  }

  @override
  Future<List<GoogleCalendarInfo>> listCalendars() async {
    return const [
      GoogleCalendarInfo(id: 'primary', summary: 'Principal', primary: true),
    ];
  }

  @override
  Future<String> createEvent(
    String calendarId,
    GoogleCalendarEventData data,
  ) async {
    created.add((calendarId: calendarId, data: data));
    return 'evt-${created.length}';
  }

  @override
  Future<void> updateEvent(
    String calendarId,
    String eventId,
    GoogleCalendarEventData data,
  ) async {
    if (failUpdate404) {
      throw const GoogleCalendarHttpException(404, 'not found');
    }
    updated.add((calendarId: calendarId, eventId: eventId, data: data));
  }

  @override
  Future<void> deleteEvent(String calendarId, String eventId) async {
    if (failDelete404) {
      throw const GoogleCalendarHttpException(404, 'not found');
    }
    deleted.add((calendarId: calendarId, eventId: eventId));
  }
}

void main() {
  late EncryptionService encryption;
  late CompromissoService compromissos;
  late ConfiguracoesService configuracoes;
  late _FakeGoogleCalendarApi api;
  late GoogleCalendarService service;

  setUpAll(() async {
    Hive.init('test/temp_hive/google_calendar');
    Hive.registerAdapters();
    await Hive.openBox<String>('encryption_meta');
    await Hive.openBox<String>('app_config');
    await Hive.openBox<Compromisso>('compromissos');
  });

  setUp(() async {
    await Hive.box<String>('encryption_meta').clear();
    await Hive.box<String>('app_config').clear();
    await Hive.box<Compromisso>('compromissos').clear();
    encryption = EncryptionService();
    await encryption.inicializar();
    await encryption.gerarChave();
    compromissos = CompromissoService(encryption: encryption);
    configuracoes = ConfiguracoesService(encryption: encryption);
    api = _FakeGoogleCalendarApi();
    service = GoogleCalendarService(
      api: api,
      compromissoService: compromissos,
      configuracoes: configuracoes,
    );
    await configuracoes.setGoogleCalendarAtivo(true);
  });

  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('compromissos');
    await Hive.deleteBoxFromDisk('app_config');
    await Hive.deleteBoxFromDisk('encryption_meta');
  });

  Compromisso novo({
    String id = 'c1',
    String tipo = 'sessao',
    String modalidade = 'online',
    String sala = 'Sala 2',
    String titulo = '',
  }) {
    return Compromisso(
      id: id,
      pacienteId: 'p1',
      dataHoraInicio: DateTime(2026, 11, 3, 14),
      dataHoraFim: DateTime(2026, 11, 3, 15),
      titulo: titulo,
      tipoEvento: tipo,
      modalidade: modalidade,
      sala: sala,
    );
  }

  test(
    'cria evento genérico sem nome de paciente e persiste metadados',
    () async {
      final c = novo();
      await compromissos.adicionar(c);

      final resultado = await service.syncCompromisso(c);

      expect(resultado.status, GoogleCalendarSyncStatus.created);
      expect(api.created, hasLength(1));
      final enviado = api.created.single.data;
      expect(enviado.summary, 'Sessão');
      expect(enviado.location, 'Sala 2');
      expect(enviado.start.toUtc(), c.dataHoraInicio.toUtc());
      expect(enviado.privateProperties['mentall_compromisso_id'], 'c1');

      final persistido = compromissos.obterPorId('c1');
      expect(persistido!.googleEventId, 'evt-1');
      expect(persistido.googleCalendarId, 'primary');
      expect(persistido.googleSyncedAt, isNotNull);
    },
  );

  test('evento geral usa o título e não usa nome de paciente', () async {
    final c = novo(tipo: 'evento_geral', titulo: 'Supervisão');
    await compromissos.adicionar(c);

    await service.syncCompromisso(c);

    expect(api.created.single.data.summary, 'Supervisão');
  });

  test('edita o evento existente em vez de criar outro', () async {
    final c = novo();
    await compromissos.adicionar(c);
    await service.syncCompromisso(c);

    c.dataHoraInicio = DateTime(2026, 11, 4, 10);
    c.dataHoraFim = DateTime(2026, 11, 4, 11);
    c.titulo = 'Editado';
    await service.syncCompromisso(c);

    expect(api.created, hasLength(1));
    expect(api.updated, hasLength(1));
    expect(api.updated.single.eventId, 'evt-1');
    expect(api.updated.single.data.start.toUtc(), c.dataHoraInicio.toUtc());
  });

  test('404 na edição recria o evento', () async {
    final c = novo();
    await compromissos.adicionar(c);
    await service.syncCompromisso(c);

    api.failUpdate404 = true;
    await service.syncCompromisso(c);

    expect(api.created, hasLength(2));
    expect(api.updated, isEmpty);
    expect(compromissos.obterPorId('c1')!.googleEventId, 'evt-2');
  });

  test('remove evento e limpa metadados; 404 é ignorado', () async {
    final c = novo();
    await compromissos.adicionar(c);
    await service.syncCompromisso(c);
    final sincronizado = compromissos.obterPorId('c1')!;

    api.failDelete404 = true;
    await service.removeEvento(sincronizado);

    expect(api.deleted, isEmpty);
    expect(compromissos.obterPorId('c1')!.googleEventId, '');
  });

  test('auto-sync desligado não cria evento; force cria', () async {
    await configuracoes.setGoogleCalendarAutoSync(false);
    final c = novo();
    await compromissos.adicionar(c);

    final skipped = await service.syncCompromisso(c);
    expect(skipped.status, GoogleCalendarSyncStatus.skipped);
    expect(api.created, isEmpty);

    final forced = await service.syncCompromisso(c, force: true);
    expect(forced.status, GoogleCalendarSyncStatus.created);
    expect(api.created, hasLength(1));
  });
}
