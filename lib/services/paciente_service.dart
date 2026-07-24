import 'package:hive_ce/hive.dart';

import '../models/paciente.dart';
import '../models/sessao.dart';
import '../models/compromisso.dart';
import '../models/contrato_terapeutico.dart';
import 'encryption_service.dart';

class PacienteService {
  final Box<Paciente> _box = Hive.box<Paciente>('pacientes');
  final EncryptionService? _encryption;

  PacienteService({EncryptionService? encryption}) : _encryption = encryption;

  List<Paciente> listarPacientes() {
    final pacientes = _box.values.toList();
    _ordenarPorNome(pacientes);
    _decryptPacientes(pacientes);
    return pacientes;
  }

  List<Paciente> listarPacientesAtivos() {
    final pacientes = _box.values
        .where((paciente) => paciente.ativo)
        .toList();
    _ordenarPorNome(pacientes);
    _decryptPacientes(pacientes);
    return pacientes;
  }

  List<Paciente> listarPacientesArquivados() {
    final pacientes = _box.values
        .where((paciente) => !paciente.ativo)
        .toList();
    _ordenarPorNome(pacientes);
    _decryptPacientes(pacientes);
    return pacientes;
  }

  List<Paciente> buscarPacientesPorNome(String termoBusca) {
    final termoNormalizado = termoBusca.trim().toLowerCase();

    if (termoNormalizado.isEmpty) {
      return listarPacientesAtivos();
    }

    final pacientes = _box.values.where((paciente) {
      final nome = _decrypt(paciente.nome).toLowerCase();
      return paciente.ativo && nome.contains(termoNormalizado);
    }).toList();

    _decryptPacientes(pacientes);
    _ordenarPorNome(pacientes);

    return pacientes;
  }

  Paciente? buscarPacientePorId(String id) {
    final idNormalizado = id.trim();

    if (idNormalizado.isEmpty) {
      return null;
    }

    final match = _box.values.where(
      (paciente) => paciente.id == idNormalizado,
    );
    if (match.isEmpty) return null;

    final paciente = match.first;
    _decryptPaciente(paciente);
    return paciente;
  }

  bool existePacienteComId(String id) {
    return buscarPacientePorId(id) != null;
  }

  Future<void> adicionarPaciente(Paciente paciente) async {
    _encryptPaciente(paciente);
    await _box.add(paciente);
    _decryptPaciente(paciente);
  }

  Future<void> atualizarPaciente(Paciente paciente) async {
    paciente.dataAtualizacao = DateTime.now();
    _encryptPaciente(paciente);
    await paciente.save();
    _decryptPaciente(paciente);
  }

  Future<void> arquivarPaciente(Paciente paciente) async {
    paciente.ativo = false;
    paciente.dataAtualizacao = DateTime.now();
    _encryptPaciente(paciente);
    await paciente.save();
    _decryptPaciente(paciente);
  }

  Future<void> restaurarPaciente(Paciente paciente) async {
    paciente.ativo = true;
    paciente.dataAtualizacao = DateTime.now();
    _encryptPaciente(paciente);
    await paciente.save();
    _decryptPaciente(paciente);
  }

  Future<void> excluirPaciente(Paciente paciente) async {
    final sessoesBox = Hive.box<Sessao>('sessoes');
    final sessoesParaExcluir = sessoesBox.values
        .where((s) => s.pacienteId == paciente.id)
        .toList();
    for (final s in sessoesParaExcluir) {
      await s.delete();
    }

    final compromissosBox = Hive.box<Compromisso>('compromissos');
    final compromissosParaExcluir = compromissosBox.values
        .where((c) => c.pacienteId == paciente.id)
        .toList();
    for (final c in compromissosParaExcluir) {
      await c.delete();
    }

    final contratosBox = Hive.box<ContratoTerapeutico>('contratos');
    final contratosParaExcluir = contratosBox.values
        .where((c) => c.pacienteId == paciente.id)
        .toList();
    for (final c in contratosParaExcluir) {
      await c.delete();
    }

    await paciente.delete();
  }

  Future<void> removerCriptografiaExistente() async {
    if (_encryption == null || !_encryption.configurado) return;

    for (final p in _box.values) {
      _decryptPaciente(p);
      await p.save();
    }
  }

  Stream<BoxEvent> observarPacientes() {
    return _box.watch();
  }

  void _ordenarPorNome(List<Paciente> pacientes) {
    pacientes.sort((a, b) {
      final nomeA = _decrypt(a.nome).trim().toLowerCase();
      final nomeB = _decrypt(b.nome).trim().toLowerCase();
      return nomeA.compareTo(nomeB);
    });
  }

  String _encrypt(String value) {
    if (_encryption == null || value.isEmpty) return value;
    return _encryption.criptografar(value);
  }

  String _decrypt(String value) {
    if (_encryption == null || value.isEmpty) return value;
    return _encryption.descriptografar(value);
  }

  void _encryptPaciente(Paciente p) {
    p.nome = _encrypt(p.nome);
    p.contato = _encrypt(p.contato);
    p.email = _encrypt(p.email);
    p.observacoes = _encrypt(p.observacoes);
  }

  void _decryptPaciente(Paciente p) {
    p.nome = _decrypt(p.nome);
    p.contato = _decrypt(p.contato);
    p.email = _decrypt(p.email);
    p.observacoes = _decrypt(p.observacoes);
  }

  void _decryptPacientes(List<Paciente> pacientes) {
    for (final p in pacientes) {
      _decryptPaciente(p);
    }
  }
}
