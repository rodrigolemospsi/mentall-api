import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/compromisso.dart';
import 'package:prontuario_tcc/providers/service_providers.dart';
import 'package:prontuario_tcc/screens/google_calendar_page.dart';
import 'package:prontuario_tcc/services/compromisso_service.dart';
import 'package:prontuario_tcc/services/configuracoes_service.dart';
import 'package:prontuario_tcc/services/google_calendar_api.dart';
import 'package:prontuario_tcc/services/google_calendar_service.dart';

class _FakeConfig extends ConfiguracoesService {
  bool ativo = false;
  String calendario = 'primary';
  bool autoSync = true;
  DateTime? ultimoSync;

  @override
  bool get googleCalendarAtivo => ativo;

  @override
  Future<void> setGoogleCalendarAtivo(bool value) async => ativo = value;

  @override
  String get googleCalendarId => calendario;

  @override
  Future<void> setGoogleCalendarId(String value) async => calendario = value;

  @override
  bool get googleCalendarAutoSync => autoSync;

  @override
  Future<void> setGoogleCalendarAutoSync(bool value) async => autoSync = value;

  @override
  DateTime? get googleCalendarUltimoSync => ultimoSync;

  @override
  Future<void> setGoogleCalendarUltimoSync(DateTime? value) async {
    ultimoSync = value;
  }
}

class _FakeApi implements GoogleCalendarApi {
  bool connected = false;

  @override
  Future<GoogleCalendarAccount?> currentAccount() async {
    return connected
        ? const GoogleCalendarAccount(
            email: 'teste@example.com',
            displayName: 'Teste',
          )
        : null;
  }

  @override
  Future<GoogleCalendarAccount> connect() async {
    connected = true;
    return const GoogleCalendarAccount(
      email: 'teste@example.com',
      displayName: 'Teste',
    );
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
  ) async => 'evt-1';

  @override
  Future<void> updateEvent(
    String calendarId,
    String eventId,
    GoogleCalendarEventData data,
  ) async {}

  @override
  Future<void> deleteEvent(String calendarId, String eventId) async {}
}

void main() {
  late _FakeConfig config;
  late _FakeApi api;
  late CompromissoService compromissos;
  late GoogleCalendarService googleService;

  setUpAll(() async {
    Hive.init('test/temp_hive/google_calendar_page_test');
    Hive.registerAdapters();
    await Hive.openBox<Compromisso>('compromissos');
  });

  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('compromissos');
  });

  setUp(() async {
    await Hive.box<Compromisso>('compromissos').clear();
    config = _FakeConfig();
    api = _FakeApi();
    compromissos = CompromissoService();
    googleService = GoogleCalendarService(
      api: api,
      compromissoService: compromissos,
      configuracoes: config,
    );
  });

  testWidgets('mostra conectar e depois a conta conectada', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          googleCalendarServiceProvider.overrideWithValue(googleService),
          configuracoesServiceProvider.overrideWithValue(config),
          compromissoServiceProvider.overrideWithValue(compromissos),
        ],
        child: const MaterialApp(home: GoogleCalendarPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conectar Google Calendar'), findsOneWidget);

    await tester.tap(find.text('Conectar Google Calendar'));
    await tester.pumpAndSettle();

    expect(find.text('teste@example.com'), findsOneWidget);
    expect(find.text('Desconectar'), findsOneWidget);
    expect(find.textContaining('Principal'), findsOneWidget);
  });
}
