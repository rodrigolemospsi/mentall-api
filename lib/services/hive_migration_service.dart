import 'package:hive_ce/hive.dart';

import '../models/paciente.dart';
import '../models/perfil_profissional.dart';
import '../models/sessao.dart';
import 'logger.dart';

class HiveMigrationService {
  static const int _schemaVersaoAtual = 3;

  static const String _metaBoxName = 'schema_meta';
  static const String _versaoKey = 'schema_versao';

  Future<void> executar() async {
    final metaBox = await Hive.openBox(_metaBoxName);
    final versaoAtual = metaBox.get(_versaoKey, defaultValue: 1) as int;

    if (versaoAtual >= _schemaVersaoAtual) {
      await metaBox.close();
      return;
    }

    Log.info(
      'HiveMigration: schema versao $versaoAtual -> $_schemaVersaoAtual',
    );

    for (int v = versaoAtual; v < _schemaVersaoAtual; v++) {
      await _executarMigracao(v + 1);
    }

    await metaBox.put(_versaoKey, _schemaVersaoAtual);
    await metaBox.close();
    Log.info('HiveMigration: concluida (versao $_schemaVersaoAtual)');
  }

  Future<void> _executarMigracao(int versaoDestino) async {
    switch (versaoDestino) {
      case 2:
        await _migracaoV2();
        break;
      case 3:
        await _migracaoV3();
        break;
      default:
        Log.erro(
          Exception('Migracao desconhecida: v$versaoDestino'),
          contexto: 'HiveMigrationService',
        );
    }
  }

  /// V2: Leitura-reescrita de todos os registros para garantir que
  /// campos adicionados posteriormente (email, dataCriacao, etc.)
  /// sejam persistidos no formato binario atual.
  Future<void> _migracaoV2() async {
    final pacientesBox = Hive.box<Paciente>('pacientes');
    final sessoesBox = Hive.box<Sessao>('sessoes');
    final perfilBox = Hive.box<PerfilProfissional>('perfil_profissional');

    int total = 0;

    for (final key in pacientesBox.keys.toList()) {
      try {
        final paciente = pacientesBox.get(key);
        if (paciente != null) {
          await paciente.save();
          total++;
        }
      } catch (_) {}
    }

    for (final key in sessoesBox.keys.toList()) {
      try {
        final sessao = sessoesBox.get(key);
        if (sessao != null) {
          if (sessao.origemRelato.isEmpty) {
            sessao.origemRelato = 'manual';
          }
          if (sessao.statusProcessamento.isEmpty) {
            sessao.statusProcessamento = 'manual';
          }
          await sessao.save();
          total++;
        }
      } catch (_) {}
    }

    for (final key in perfilBox.keys.toList()) {
      try {
        final perfil = perfilBox.get(key);
        if (perfil != null) {
          await perfil.save();
          total++;
        }
      } catch (_) {}
    }

    if (total > 0) {
      Log.info('HiveMigration V2: $total registros reescritos');
    }
  }

  Future<void> _migracaoV3() async {
    final pacientesBox = Hive.box<Paciente>('pacientes');
    final sessoesBox = Hive.box<Sessao>('sessoes');
    final perfilBox = Hive.box<PerfilProfissional>('perfil_profissional');

    int total = 0;

    for (final key in pacientesBox.keys.toList()) {
      try {
        final paciente = pacientesBox.get(key);
        if (paciente != null) {
          await paciente.save();
          total++;
        }
      } catch (_) {}
    }

    for (final key in sessoesBox.keys.toList()) {
      try {
        final sessao = sessoesBox.get(key);
        if (sessao != null) {
          await sessao.save();
          total++;
        }
      } catch (_) {}
    }

    for (final key in perfilBox.keys.toList()) {
      try {
        final perfil = perfilBox.get(key);
        if (perfil != null) {
          await perfil.save();
          total++;
        }
      } catch (_) {}
    }

    if (total > 0) {
      Log.info('HiveMigration V3: $total registros reescritos');
    }
  }
}
