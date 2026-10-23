import 'package:flutter_test/flutter_test.dart';
import 'package:prontuario_tcc/models/compromisso.dart';

void main() {
  Compromisso novo() => Compromisso(
    id: 'c1',
    pacienteId: 'p1',
    dataHoraInicio: DateTime(2026, 10, 20, 10),
  );

  test('novo compromisso usa defaults de sessão presencial', () {
    final c = novo();

    expect(c.tipoEvento, 'sessao');
    expect(c.modalidade, 'presencial');
    expect(c.sala, '');
    expect(c.servico, '');
    expect(c.linkOnline, '');
    expect(c.googleEventId, '');
    expect(c.googleCalendarId, '');
    expect(c.googleSyncedAt, isNull);
    expect(c.ehEventoGeral, false);
    expect(c.ehOnline, false);
  });

  test('copyWith preserva os novos campos', () {
    final c = novo().copyWith(
      tipoEvento: 'evento_geral',
      modalidade: 'online',
      sala: 'Sala 2',
      servico: 'Supervisão',
      linkOnline: 'https://meet.example/x',
      googleEventId: 'evt-1',
      googleCalendarId: 'primary',
      googleSyncedAt: DateTime(2026, 10, 20, 12),
    );

    expect(c.tipoEvento, 'evento_geral');
    expect(c.modalidade, 'online');
    expect(c.sala, 'Sala 2');
    expect(c.servico, 'Supervisão');
    expect(c.linkOnline, 'https://meet.example/x');
    expect(c.googleEventId, 'evt-1');
    expect(c.googleCalendarId, 'primary');
    expect(c.googleSyncedAt, DateTime(2026, 10, 20, 12));
    expect(c.ehEventoGeral, true);
    expect(c.ehOnline, true);
  });
}
