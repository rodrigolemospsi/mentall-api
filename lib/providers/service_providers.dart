import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/paciente.dart';
import '../services/audio_relato_service.dart';
import '../services/auth_service.dart';
import '../services/encryption_service.dart';
import '../services/ia_clinica_service.dart';
import '../services/paciente_service.dart';
import '../services/perfil_profissional_service.dart';
import '../services/sessao_service.dart';
import '../services/backup_service.dart';
import '../services/lgpd/auditoria_service.dart';
import '../models/compromisso.dart';
import '../services/compromisso_service.dart';
import '../services/lembrete_service.dart';
import '../services/transcricao_relato_service.dart';

final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  final encryption = ref.watch(encryptionServiceProvider);
  return AuthService(encryption);
});

final pacienteServiceProvider = Provider<PacienteService>((ref) {
  final encryption = ref.watch(encryptionServiceProvider);
  return PacienteService(encryption: encryption);
});

final perfilProfissionalServiceProvider = Provider<PerfilProfissionalService>((ref) {
  final encryption = ref.watch(encryptionServiceProvider);
  return PerfilProfissionalService(encryption: encryption);
});

final sessaoServiceProvider = Provider<SessaoService>((ref) {
  final encryption = ref.watch(encryptionServiceProvider);
  return SessaoService(encryption: encryption);
});

final pacientesAtivosProvider = StreamProvider<List<Paciente>>((ref) async* {
  final service = ref.watch(pacienteServiceProvider);
  yield service.listarPacientesAtivos();
  await for (final _ in service.observarPacientes()) {
    yield service.listarPacientesAtivos();
  }
});

final pacientesArquivadosProvider = StreamProvider<List<Paciente>>((ref) async* {
  final service = ref.watch(pacienteServiceProvider);
  yield service.listarPacientesArquivados();
  await for (final _ in service.observarPacientes()) {
    yield service.listarPacientesArquivados();
  }
});

final audioRelatoServiceProvider = Provider<AudioRelatoService>((ref) {
  return AudioRelatoService();
});

final transcricaoRelatoServiceProvider = Provider<TranscricaoRelatoService>((ref) {
  return TranscricaoRelatoService();
});

final iaClinicaServiceProvider = Provider<IaClinicaService>((ref) {
  return IaClinicaService();
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
});

final auditoriaServiceProvider = Provider<AuditoriaService>((ref) {
  return AuditoriaService();
});

final compromissoServiceProvider = Provider<CompromissoService>((ref) {
  return CompromissoService();
});

final lembreteServiceProvider = Provider<LembreteService>((ref) {
  return LembreteService();
});

final compromissosHojeProvider = StreamProvider<List<Compromisso>>((ref) async* {
  final service = ref.watch(compromissoServiceProvider);
  yield service.listarHoje();
  await for (final _ in service.observar()) {
    yield service.listarHoje();
  }
});
