import 'package:hive_ce/hive.dart';

import '../models/paciente.dart';

class PacienteService {
  final Box<Paciente> _box = Hive.box<Paciente>('pacientes');

  List<Paciente> listarPacientes() {
    final pacientes = _box.values.toList();

    _ordenarPorNome(pacientes);

    return pacientes;
  }

  List<Paciente> listarPacientesAtivos() {
    final pacientes = _box.values
        .where((paciente) => paciente.ativo)
        .toList();

    _ordenarPorNome(pacientes);

    return pacientes;
  }

  List<Paciente> listarPacientesArquivados() {
    final pacientes = _box.values
        .where((paciente) => !paciente.ativo)
        .toList();

    _ordenarPorNome(pacientes);

    return pacientes;
  }

  List<Paciente> buscarPacientesPorNome(String termoBusca) {
    final termoNormalizado = termoBusca.trim().toLowerCase();

    if (termoNormalizado.isEmpty) {
      return listarPacientesAtivos();
    }

    final pacientes = _box.values.where((paciente) {
      final nomeNormalizado = paciente.nome.trim().toLowerCase();

      return paciente.ativo && nomeNormalizado.contains(termoNormalizado);
    }).toList();

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
    return match.isNotEmpty ? match.first : null;
  }

  bool existePacienteComId(String id) {
    return buscarPacientePorId(id) != null;
  }

  Future<void> adicionarPaciente(Paciente paciente) async {
    await _box.add(paciente);
  }

  Future<void> atualizarPaciente(Paciente paciente) async {
    await paciente.save();
  }

  Future<void> arquivarPaciente(Paciente paciente) async {
    paciente.ativo = false;
    await paciente.save();
  }

  Future<void> restaurarPaciente(Paciente paciente) async {
    paciente.ativo = true;
    await paciente.save();
  }

  Future<void> excluirPaciente(Paciente paciente) async {
    await paciente.delete();
  }

  Stream<BoxEvent> observarPacientes() {
    return _box.watch();
  }

  void _ordenarPorNome(List<Paciente> pacientes) {
    pacientes.sort((a, b) {
      final nomeA = a.nome.trim().toLowerCase();
      final nomeB = b.nome.trim().toLowerCase();

      return nomeA.compareTo(nomeB);
    });
  }
}