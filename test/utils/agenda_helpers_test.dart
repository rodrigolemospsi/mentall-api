import 'package:flutter_test/flutter_test.dart';
import 'package:prontuario_tcc/models/compromisso.dart';
import 'package:prontuario_tcc/utils/agenda_helpers.dart';

void main() {
  Compromisso c(
    String id, {
    String tipo = 'sessao',
    String modalidade = 'presencial',
    String sala = '',
  }) {
    return Compromisso(
      id: id,
      pacienteId: 'p1',
      dataHoraInicio: DateTime(2026, 10, 20, 10),
      titulo: id,
      tipoEvento: tipo,
      modalidade: modalidade,
      sala: sala,
    );
  }

  test('filtra por tipo de evento', () {
    final lista = [c('s1'), c('e1', tipo: 'evento_geral'), c('s2')];

    final filtrados = filtrarCompromissos(lista, tipo: 'evento_geral');

    expect(filtrados.map((x) => x.id), ['e1']);
  });

  test('filtra por modalidade', () {
    final lista = [c('p1'), c('o1', modalidade: 'online')];

    final filtrados = filtrarCompromissos(lista, modalidade: 'online');

    expect(filtrados.map((x) => x.id), ['o1']);
  });

  test('agrupa por sala e usa "Sem sala" quando vazio', () {
    final grupos = agruparPorSala([
      c('a', sala: 'Sala 2'),
      c('b'),
      c('c', sala: 'Sala 2'),
      c('d', sala: 'Sala 1'),
    ]);

    expect(grupos.keys, containsAll(['Sala 2', 'Sala 1', 'Sem sala']));
    expect(grupos['Sala 2']!.map((x) => x.id), ['a', 'c']);
    expect(grupos['Sem sala']!.map((x) => x.id), ['b']);
  });
}
