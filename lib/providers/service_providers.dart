import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/paciente.dart';
import '../models/contrato_terapeutico.dart';
import '../services/audio_relato_service.dart';
import '../services/auth_service.dart';
import '../services/contrato_service.dart';
import '../services/encryption_service.dart';
import '../services/ia_clinica_service.dart';
import '../services/paciente_service.dart';
import '../services/perfil_profissional_service.dart';
import '../services/sessao_service.dart';
import '../services/backup_service.dart';
import '../services/lgpd/auditoria_service.dart';
import '../models/compromisso.dart';
import '../models/lgpd/registro_auditoria.dart';
import '../services/compromisso_service.dart';
import '../services/configuracoes_service.dart';
import '../services/lembrete_service.dart';
import '../services/transcricao_relato_service.dart';

final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  final encryption = ref.watch(encryptionServiceProvider);
  final pacienteService = ref.watch(pacienteServiceProvider);
  final sessaoService = ref.watch(sessaoServiceProvider);
  final perfilProfissionalService = ref.watch(perfilProfissionalServiceProvider);
  return AuthService(
    encryption,
    pacienteService: pacienteService,
    sessaoService: sessaoService,
    perfilProfissionalService: perfilProfissionalService,
  );
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
  final encryption = ref.watch(encryptionServiceProvider);
  return BackupService(encryption: encryption);
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

final configuracoesServiceProvider = Provider<ConfiguracoesService>((ref) {
  return ConfiguracoesService();
});

final configuracoesRevisaoProvider = StreamProvider<int>((ref) async* {
  final service = ref.watch(configuracoesServiceProvider);
  var revisao = 0;
  yield revisao;
  await for (final _ in service.observar()) {
    yield ++revisao;
  }
});

final compromissosHojeProvider = StreamProvider<List<Compromisso>>((ref) async* {
  final service = ref.watch(compromissoServiceProvider);
  yield service.listarHoje();
  await for (final _ in service.observar()) {
    yield service.listarHoje();
  }
});

final compromissosPorDataProvider = StreamProvider.autoDispose.family<List<Compromisso>, DateTime>((ref, date) async* {
  final service = ref.watch(compromissoServiceProvider);
  yield service.listarPorData(date);
  await for (final _ in service.observar()) {
    yield service.listarPorData(date);
  }
});

final atividadeRecenteProvider = StreamProvider<List<RegistroAuditoria>>((ref) async* {
  final service = ref.watch(auditoriaServiceProvider);
  yield service.listar(limite: 5);
  await for (final _ in service.observar()) {
    yield service.listar(limite: 5);
  }
});

class DashboardKpisSessoes {
  final int sessoesUltimos30Dias;
  final int pendentesRevisao;

  const DashboardKpisSessoes({
    required this.sessoesUltimos30Dias,
    required this.pendentesRevisao,
  });
}

final dashboardKpisSessoesProvider =
    StreamProvider<DashboardKpisSessoes>((ref) async* {
  final service = ref.watch(sessaoServiceProvider);

  DashboardKpisSessoes calcular() {
    final limite = DateTime.now().subtract(const Duration(days: 30));
    final sessoes30 = service
        .listarTodasSessoesAtivas()
        .where((s) => s.data.isAfter(limite))
        .length;
    return DashboardKpisSessoes(
      sessoesUltimos30Dias: sessoes30,
      pendentesRevisao: service.contarSessoesPendentesRevisao(),
    );
  }

  yield calcular();
  await for (final _ in service.observarSessoes()) {
    yield calcular();
  }
});

final contratoServiceProvider = Provider<ContratoService>((ref) {
  return ContratoService();
});

final contratoPorPacienteProvider =
    StreamProvider.autoDispose.family<ContratoTerapeutico?, String>((ref, pacienteId) async* {
  final service = ref.watch(contratoServiceProvider);
  yield service.obterPorPaciente(pacienteId);
  await for (final _ in service.observar()) {
    yield service.obterPorPaciente(pacienteId);
  }
});
