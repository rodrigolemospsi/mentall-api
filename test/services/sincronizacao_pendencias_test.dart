import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/anamnese_enviada.dart';
import 'package:prontuario_tcc/models/contrato_terapeutico.dart';
import 'package:prontuario_tcc/services/anamnese_enviada_service.dart';
import 'package:prontuario_tcc/services/contrato_service.dart';

class _FakeContratoService extends ContratoService {
  _FakeContratoService(this._respostas);

  final Map<String, bool> _respostas;
  final List<String> _chamados = [];

  @override
  Future<bool> verificarStatus(ContratoTerapeutico contrato) async {
    _chamados.add(contrato.id);
    return _respostas[contrato.id] ?? false;
  }
}

class _FakeAnamneseService extends AnamneseEnviadaService {
  _FakeAnamneseService(this._respostas);

  final Map<String, bool> _respostas;
  final List<String> _chamados = [];

  @override
  Future<bool> verificarStatus(AnamneseEnviada anamnese) async {
    _chamados.add(anamnese.id);
    return _respostas[anamnese.id] ?? false;
  }
}

void main() {
  setUpAll(() async {
    Hive.init('test/temp_hive/sync_pendencias');
    Hive.registerAdapters();
    await Hive.openBox<ContratoTerapeutico>('contratos');
    await Hive.openBox('anamneses_enviadas');
  });

  tearDownAll(() async {
    await Hive.box<ContratoTerapeutico>('contratos').close();
    await Hive.box('anamneses_enviadas').close();
    await Hive.deleteBoxFromDisk('contratos');
    await Hive.deleteBoxFromDisk('anamneses_enviadas');
  });

  setUp(() async {
    await Hive.box<ContratoTerapeutico>('contratos').clear();
    await Hive.box('anamneses_enviadas').clear();
  });

  ContratoTerapeutico contrato(
    String id,
    String pacienteId,
    String status,
  ) {
    return ContratoTerapeutico(
      id: id,
      pacienteId: pacienteId,
      token: 'token-$id',
      dataCriacao: DateTime(2026, 8, 1),
      status: status,
    );
  }

  AnamneseEnviada anamnese(
    String id,
    String pacienteId,
    String status,
  ) {
    return AnamneseEnviada(
      id: id,
      pacienteId: pacienteId,
      token: 'token-$id',
      abordagem: 'TCC',
      status: status,
      url: 'https://x/$id',
      dataCriacao: DateTime(2026, 8, 1),
    );
  }

  group('ContratoService.sincronizarPendencias', () {
    test('verifica apenas pendentes/enviados e ignora aceitos', () async {
      await Hive.box<ContratoTerapeutico>('contratos').putAll({
        'c1': contrato('c1', 'p1', 'enviado'),
        'c2': contrato('c2', 'p1', 'pendente'),
        'c3': contrato('c3', 'p1', 'aceito'),
      });
      final service = _FakeContratoService({'c1': true, 'c2': false});

      final atualizados = await service.sincronizarPendencias();

      expect(atualizados, 1);
      expect(service._chamados.toSet(), {'c1', 'c2'});
    });

    test('filtra por pacienteId', () async {
      await Hive.box<ContratoTerapeutico>('contratos').putAll({
        'c1': contrato('c1', 'p1', 'enviado'),
        'c2': contrato('c2', 'p2', 'enviado'),
      });
      final service = _FakeContratoService({'c1': true});

      await service.sincronizarPendencias(pacienteId: 'p1');

      expect(service._chamados, ['c1']);
    });

    test('retorna zero quando nao ha pendentes', () async {
      await Hive.box<ContratoTerapeutico>('contratos')
          .put('c1', contrato('c1', 'p1', 'aceito'));
      final service = _FakeContratoService({});

      final atualizados = await service.sincronizarPendencias();

      expect(atualizados, 0);
      expect(service._chamados, isEmpty);
    });
  });

  group('AnamneseEnviadaService.sincronizarPendencias', () {
    test('verifica apenas pendentes/enviados e ignora respondidos', () async {
      await Hive.box('anamneses_enviadas').putAll({
        'a1': anamnese('a1', 'p1', 'enviado'),
        'a2': anamnese('a2', 'p1', 'pendente'),
        'a3': anamnese('a3', 'p1', 'respondido'),
      });
      final service = _FakeAnamneseService({'a1': true, 'a2': false});

      final atualizadas = await service.sincronizarPendencias();

      expect(atualizadas, 1);
      expect(service._chamados.toSet(), {'a1', 'a2'});
    });

    test('filtra por pacienteId', () async {
      await Hive.box('anamneses_enviadas').putAll({
        'a1': anamnese('a1', 'p1', 'enviado'),
        'a2': anamnese('a2', 'p2', 'enviado'),
      });
      final service = _FakeAnamneseService({'a1': true});

      await service.sincronizarPendencias(pacienteId: 'p1');

      expect(service._chamados, ['a1']);
    });
  });
}
