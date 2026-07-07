import 'package:hive_ce/hive.dart';

import '../models/perfil_profissional.dart';

class PerfilProfissionalService {
  final Box<PerfilProfissional> _box =
      Hive.box<PerfilProfissional>('perfil_profissional');

  PerfilProfissional? obterPerfil() {
    if (_box.isEmpty) {
      return null;
    }

    return _box.values.first;
  }

  bool perfilConfigurado() {
    return obterPerfil() != null;
  }

  Future<void> salvarPerfil(PerfilProfissional perfil) async {
    if (_box.isEmpty) {
      await _box.add(perfil);
      return;
    }

    final perfilExistente = _box.values.first;

    perfilExistente.nome = perfil.nome;
    perfilExistente.registroProfissional = perfil.registroProfissional;
    perfilExistente.abordagemClinica = perfil.abordagemClinica;
    perfilExistente.termoPessoaAtendida = perfil.termoPessoaAtendida;

    await perfilExistente.save();
  }

  Future<void> atualizarPerfil(PerfilProfissional perfil) async {
    await perfil.save();
  }

  Future<void> limparPerfil() async {
    await _box.clear();
  }

  Stream<BoxEvent> observarPerfil() {
    return _box.watch();
  }
}