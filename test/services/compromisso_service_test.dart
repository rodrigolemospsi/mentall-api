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
    final agora = DateTime.now();
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

    final lidos = service.listarPorData(DateTime.now());
    expect(lidos, hasLength(1));

    await service.marcarComoRealizado(lidos.first);

    final relido = service.obterPorId('c1');
    expect(relido, isNotNull);
    expect(relido!.statusEnum, StatusCompromisso.realizado);
  });

  test('marcarComoCancelado persiste o status na box', () async {
    await service.adicionar(novoCompromisso('c1'));

    final lidos = service.listarPorData(DateTime.now());
    await service.marcarComoCancelado(lidos.first);

    final relido = service.obterPorId('c1');
    expect(relido!.statusEnum, StatusCompromisso.cancelado);
  });

  test('marcarComoFaltou persiste o status na box', () async {
    await service.adicionar(novoCompromisso('c1'));

    final lidos = service.listarPorData(DateTime.now());
    await service.marcarComoFaltou(lidos.first);

    final relido = service.obterPorId('c1');
    expect(relido!.statusEnum, StatusCompromisso.faltou);
  });

  test('marcarComoAgendado restaura o status agendado', () async {
    await service.adicionar(novoCompromisso('c1', status: 'realizado'));

    final lidos = service.listarPorData(DateTime.now());
    await service.marcarComoAgendado(lidos.first);

    final relido = service.obterPorId('c1');
    expect(relido!.statusEnum, StatusCompromisso.agendado);
  });

  test('remover apaga o compromisso da box', () async {
    await service.adicionar(novoCompromisso('c1'));

    final lidos = service.listarPorData(DateTime.now());
    await service.remover(lidos.first);

    expect(service.obterPorId('c1'), isNull);
  });

  test('atualizar persiste as alterações usando a key do registro', () async {
    await service.adicionar(novoCompromisso('c1'));

    final lidos = service.listarPorData(DateTime.now());
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
}
