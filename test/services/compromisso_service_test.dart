import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/compromisso.dart';
import 'package:prontuario_tcc/models/enums.dart';
import 'package:prontuario_tcc/services/compromisso_service.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';

void main() {
  late CompromissoService service;
  late EncryptionService encryption;

  setUpAll(() async {
    Hive.init('./test/temp_hive/compromisso');
    Hive.registerAdapters();
    await Hive.openBox<String>('encryption_meta');
    await Hive.openBox<Compromisso>('compromissos');
  });

  setUp(() async {
    await Hive.box<Compromisso>('compromissos').clear();
    await Hive.box<String>('encryption_meta').clear();
    encryption = EncryptionService();
    await encryption.inicializar();
    await encryption.gerarChave();
    service = CompromissoService(encryption: encryption);
  });

  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('compromissos');
    await Hive.deleteBoxFromDisk('encryption_meta');
  });

  Compromisso novoCompromisso(String id, {String status = 'agendado'}) {
    // Horário fixo do meio-dia: evita falha intermitente perto da meia-noite
    // (agora + 1h cruzaria para o dia seguinte e listarPorData(hoje) falharia).
    final agora = DateTime(2026, 8, 25, 12, 0);
    return Compromisso(
      id: id,
      pacienteId: 'paciente-1',
      dataHoraInicio: agora.add(const Duration(hours: 1)),
      titulo: 'Sessão de acompanhamento',
      observacoes: 'Levar material',
      status: status,
      lembreteAtivado: true,
      minutosAntecedencia: 60,
      canalLembrete: 'whatsapp',
    );
  }

  test('marcarComoRealizado persiste o status na box', () async {
    await service.adicionar(novoCompromisso('c1'));

    final lidos = service.listarPorData(DateTime(2026, 8, 25));
    expect(lidos, hasLength(1));

    await service.marcarComoRealizado(lidos.first);

    final relido = service.obterPorId('c1');
    expect(relido, isNotNull);
    expect(relido!.statusEnum, StatusCompromisso.realizado);
  });

  test('marcarComoCancelado persiste o status na box', () async {
    await service.adicionar(novoCompromisso('c1'));

    final lidos = service.listarPorData(DateTime(2026, 8, 25));
    await service.marcarComoCancelado(lidos.first);

    final relido = service.obterPorId('c1');
    expect(relido!.statusEnum, StatusCompromisso.cancelado);
  });

  test('marcarComoFaltou persiste o status na box', () async {
    await service.adicionar(novoCompromisso('c1'));

    final lidos = service.listarPorData(DateTime(2026, 8, 25));
    await service.marcarComoFaltou(lidos.first);

    final relido = service.obterPorId('c1');
    expect(relido!.statusEnum, StatusCompromisso.faltou);
  });

  test('marcarComoAgendado restaura o status agendado', () async {
    await service.adicionar(novoCompromisso('c1', status: 'realizado'));

    final lidos = service.listarPorData(DateTime(2026, 8, 25));
    await service.marcarComoAgendado(lidos.first);

    final relido = service.obterPorId('c1');
    expect(relido!.statusEnum, StatusCompromisso.agendado);
  });

  test('remover apaga o compromisso da box', () async {
    await service.adicionar(novoCompromisso('c1'));

    final lidos = service.listarPorData(DateTime(2026, 8, 25));
    await service.remover(lidos.first);

    expect(service.obterPorId('c1'), isNull);
  });

  test('atualizar persiste as alterações usando a key do registro', () async {
    await service.adicionar(novoCompromisso('c1'));

    final lidos = service.listarPorData(DateTime(2026, 8, 25));
    final editado = Compromisso(
      id: lidos.first.id,
      pacienteId: lidos.first.pacienteId,
      dataHoraInicio: lidos.first.dataHoraInicio,
      titulo: 'Sessão editada',
      observacoes: 'Novas observações',
      status: 'agendado',
      lembreteAtivado: true,
      minutosAntecedencia: 120,
      canalLembrete: 'whatsapp',
    );
    await service.atualizar(editado);

    final relido = service.obterPorId('c1');
    expect(relido, isNotNull);
    expect(relido!.titulo, 'Sessão editada');
    expect(relido.observacoes, 'Novas observações');
    expect(relido.minutosAntecedencia, 120);
  });

  Compromisso recorrente(String id, {DateTime? inicio}) {
    final base = inicio ?? DateTime(2026, 9, 1, 12);
    return Compromisso(
      id: id,
      pacienteId: 'paciente-1',
      dataHoraInicio: base,
      dataHoraFim: base.add(const Duration(minutes: 50)),
      titulo: 'Sessão recorrente',
      observacoes: 'Observação recorrente',
      lembreteAtivado: true,
      minutosAntecedencia: 60,
      mensagemLembrete: 'Mensagem personalizada',
      recorrencia: FrequenciaRecorrencia.semanal.value,
      dataLimiteRecorrencia: base.add(const Duration(days: 21)),
      canalLembrete: 'whatsapp',
      modalidade: 'online',
      sala: 'Sala 2',
      servico: 'Psicoterapia',
      linkOnline: 'https://meet.example/x',
    );
  }

  test(
    'recorrência devolve todas as ocorrências com conteúdo em texto claro',
    () async {
      final gerados = await service.adicionarComRecorrencia(recorrente('pai'));

      expect(gerados.length, greaterThan(1));
      for (final c in gerados) {
        expect(c.titulo, 'Sessão recorrente');
        expect(c.observacoes, 'Observação recorrente');
        expect(c.mensagemLembrete, 'Mensagem personalizada');
      }

      for (final c in service.listarTodos()) {
        expect(c.titulo, 'Sessão recorrente');
        expect(c.mensagemLembrete, 'Mensagem personalizada');
      }
    },
  );

  test('recorrência não grava nada se uma ocorrência conflitar', () async {
    final inicioConflito = DateTime(2026, 9, 8, 12);
    await service.adicionar(
      Compromisso(
        id: 'existente',
        pacienteId: 'paciente-2',
        dataHoraInicio: inicioConflito,
        dataHoraFim: inicioConflito.add(const Duration(minutes: 50)),
      ),
    );

    expect(
      () => service.adicionarComRecorrencia(recorrente('pai')),
      throwsA(isA<ConflitoDeHorarioException>()),
    );
    await Future<void>.delayed(Duration.zero);

    expect(Hive.box<Compromisso>('compromissos').length, 1);
    expect(service.obterPorId('pai'), isNull);
  });

  test(
    'recorrência com permitirConflito grava mesmo com sobreposição',
    () async {
      final inicioConflito = DateTime(2026, 9, 8, 12);
      await service.adicionar(
        Compromisso(
          id: 'existente',
          pacienteId: 'paciente-2',
          dataHoraInicio: inicioConflito,
          dataHoraFim: inicioConflito.add(const Duration(minutes: 50)),
        ),
      );

      final gerados = await service.adicionarComRecorrencia(
        recorrente('pai'),
        permitirConflito: true,
      );

      expect(gerados.length, greaterThan(1));
      expect(service.obterPorId('pai'), isNotNull);
    },
  );

  test(
    'flag permitirConflito no próprio compromisso libera só a primeira ocorrência',
    () async {
      final inicioConflito = DateTime(2026, 9, 1, 12);
      await service.adicionar(
        Compromisso(
          id: 'existente',
          pacienteId: 'paciente-2',
          dataHoraInicio: inicioConflito,
          dataHoraFim: inicioConflito.add(const Duration(minutes: 50)),
        ),
      );

      final compromisso = recorrente('pai')..permitirConflito = true;
      final gerados = await service.adicionarComRecorrencia(compromisso);

      expect(gerados.length, greaterThan(1));
      expect(service.obterPorId('pai'), isNotNull);
    },
  );

  test(
    'flag permitirConflito não libera conflito em ocorrência futura',
    () async {
      final inicioConflito = DateTime(2026, 9, 8, 12);
      await service.adicionar(
        Compromisso(
          id: 'existente',
          pacienteId: 'paciente-2',
          dataHoraInicio: inicioConflito,
          dataHoraFim: inicioConflito.add(const Duration(minutes: 50)),
        ),
      );

      final compromisso = recorrente('pai')..permitirConflito = true;

      expect(
        () => service.adicionarComRecorrencia(compromisso),
        throwsA(isA<ConflitoDeHorarioException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(Hive.box<Compromisso>('compromissos').length, 1);
      expect(service.obterPorId('pai'), isNull);
    },
  );

  test('ocorrências recorrentes não herdam o googleEventId do pai', () async {
    final pai = recorrente('pai')..googleEventId = 'evt-pai';
    final gerados = await service.adicionarComRecorrencia(
      pai,
      permitirConflito: true,
    );

    expect(gerados.length, greaterThan(1));
    expect(gerados.first.googleEventId, 'evt-pai');
    for (final filho in gerados.skip(1)) {
      expect(filho.googleEventId, '');
    }
  });
}
