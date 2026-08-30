import 'package:flutter_test/flutter_test.dart';
import 'package:prontuario_tcc/models/sessao.dart';
import 'package:prontuario_tcc/utils/sessao_form_helpers.dart';

void main() {
  Sessao sessao() => Sessao(
        id: 's1',
        pacienteId: 'p1',
        numeroSessao: 1,
        data: DateTime(2026, 7, 15, 14, 30),
        eventosImportantes: 'Evento A',
        evolucaoClinica: 'Evolucao B',
        observacoes: 'Obs C',
        pensamentosAutomaticos: 'Pensamento X',
        emocoes: 'Emocao Y',
        comportamentos: 'Comportamento Z',
      );

  group('concatenarSintese', () {
    test('une eventos + evolucao + observacoes com quebras', () {
      expect(
        concatenarSintese(sessao()),
        'Evento A\n\nEvolucao B\n\nObs C',
      );
    });

    test('ignora campos vazios', () {
      final s = sessao()
        ..evolucaoClinica = ''
        ..observacoes = '';
      expect(concatenarSintese(s), 'Evento A');
    });
  });

  group('concatenarFormulacao', () {
    test('une pensamentos + emocoes + comportamentos', () {
      expect(
        concatenarFormulacao(sessao()),
        'Pensamento X\n\nEmocao Y\n\nComportamento Z',
      );
    });

    test('ignora campos vazios', () {
      final s = sessao()
        ..emocoes = ''
        ..comportamentos = '';
      expect(concatenarFormulacao(s), 'Pensamento X');
    });
  });

  group('formatarData / formatarHorario', () {
    test('formata data dd/mm/aaaa', () {
      expect(formatarData(DateTime(2026, 7, 5)), '05/07/2026');
    });

    test('formata horario hh:mm', () {
      expect(formatarHorario(DateTime(2026, 7, 5, 9, 7)), '09:07');
    });
  });

  group('nomeEscala', () {
    test('retorna nome conhecido', () {
      expect(nomeEscala('phq9'), 'PHQ-9 (Depressão)');
      expect(nomeEscala('gad7'), 'GAD-7 (Ansiedade)');
      expect(nomeEscala('dass21'), 'DASS-21');
    });

    test('retorna o proprio id para escala desconhecida', () {
      expect(nomeEscala('foo'), 'foo');
    });
  });
}
