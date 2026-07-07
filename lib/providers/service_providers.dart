import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/paciente.dart';
import '../services/paciente_service.dart';
import '../services/perfil_profissional_service.dart';
import '../services/sessao_service.dart';

final pacienteServiceProvider = Provider<PacienteService>((ref) {
  return PacienteService();
});

final perfilProfissionalServiceProvider = Provider<PerfilProfissionalService>((ref) {
  return PerfilProfissionalService();
});

final sessaoServiceProvider = Provider<SessaoService>((ref) {
  return SessaoService();
});

final pacientesAtivosProvider = StreamProvider<List<Paciente>>((ref) {
  final service = ref.watch(pacienteServiceProvider);
  return service.observarPacientes().map((_) => service.listarPacientesAtivos());
});

final pacientesArquivadosProvider = StreamProvider<List<Paciente>>((ref) {
  final service = ref.watch(pacienteServiceProvider);
  return service.observarPacientes().map((_) => service.listarPacientesArquivados());
});
