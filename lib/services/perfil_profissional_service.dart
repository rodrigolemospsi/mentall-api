import 'package:hive_ce/hive.dart';

import '../models/perfil_profissional.dart';
import 'encryption_service.dart';

class PerfilProfissionalService {
  final Box<PerfilProfissional> _box =
      Hive.box<PerfilProfissional>('perfil_profissional');
  final EncryptionService? _encryption;

  PerfilProfissionalService({EncryptionService? encryption})
      : _encryption = encryption;

  PerfilProfissional? obterPerfil() {
    if (_box.isEmpty) return null;

    final perfil = _box.values.first;
    _decryptPerfil(perfil);
    return perfil;
  }

  bool perfilConfigurado() {
    return obterPerfil() != null;
  }

  Future<void> salvarPerfil(PerfilProfissional perfil) async {
    if (_box.isEmpty) {
      _encryptPerfil(perfil);
      await _box.add(perfil);
      _decryptPerfil(perfil);
      return;
    }

    final perfilExistente = _box.values.first;
    _decryptPerfil(perfilExistente);

    perfilExistente.nome = perfil.nome;
    perfilExistente.registroProfissional = perfil.registroProfissional;
    perfilExistente.abordagemClinica = perfil.abordagemClinica;
    perfilExistente.termoPessoaAtendida = perfil.termoPessoaAtendida;
    perfilExistente.modalidadesAtendimentoJson = perfil.modalidadesAtendimentoJson;
    perfilExistente.enderecosConsultoriosJson = perfil.enderecosConsultoriosJson;
    perfilExistente.dataAtualizacao = DateTime.now();

    _encryptPerfil(perfilExistente);
    await perfilExistente.save();
    _decryptPerfil(perfilExistente);
  }

  Future<void> atualizarPerfil(PerfilProfissional perfil) async {
    _encryptPerfil(perfil);
    await perfil.save();
    _decryptPerfil(perfil);
  }

  Future<void> limparPerfil() async {
    await _box.clear();
  }

  Stream<BoxEvent> observarPerfil() {
    return _box.watch();
  }

  String _encrypt(String value) {
    if (_encryption == null || value.isEmpty) return value;
    return _encryption!.criptografar(value);
  }

  String _decrypt(String value) {
    if (_encryption == null || value.isEmpty) return value;
    return _encryption!.descriptografar(value);
  }

  void _encryptPerfil(PerfilProfissional p) {
    p.nome = _encrypt(p.nome);
    p.registroProfissional = _encrypt(p.registroProfissional);
  }

  void _decryptPerfil(PerfilProfissional p) {
    p.nome = _decrypt(p.nome);
    p.registroProfissional = _decrypt(p.registroProfissional);
  }
}
