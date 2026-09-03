import 'backup_service.dart';
import 'backup_storage.dart';
import 'configuracoes_service.dart';
import 'encryption_service.dart';

/// Agendamento de backup automático: decide se está na hora e executa a
/// gravação no local configurado (ou no diretório padrão do app), guardando a
/// data do último backup bem-sucedido.
class BackupAgendamentoService {
  final ConfiguracoesService configuracoes;
  final BackupService backupService;
  final EncryptionService? encryption;

  BackupAgendamentoService({
    required this.configuracoes,
    required this.backupService,
    this.encryption,
  });

  /// Regra pura de "está na hora de rodar?". Testável isoladamente.
  /// [frequencia]: 'off' | 'diario' | 'semanal' | 'mensal'.
  static bool deveExecutarAgora({
    required String frequencia,
    required DateTime? ultimoBackup,
    required DateTime agora,
  }) {
    switch (frequencia) {
      case 'diario':
      case 'semanal':
      case 'mensal':
        if (ultimoBackup == null) return true;
        final dias = switch (frequencia) {
          'diario' => 1,
          'semanal' => 7,
          _ => 30,
        };
        return agora.difference(ultimoBackup).inDays >= dias;
      case 'off':
      default:
        return false;
    }
  }

  /// Executa o backup agora (agendado ou manual). Retorna o caminho salvo ou
  /// `null` em falha. Atualiza [ConfiguracoesService.ultimoBackupEm] em sucesso.
  Future<String?> executar({String? diretorio, DateTime? agora}) async {
    try {
      var conteudo = backupService.exportarParaJson();
      if (encryption != null && encryption!.configurado) {
        final cifrado = encryption!.criptografarEnvelope(conteudo);
        if (cifrado != null) conteudo = cifrado;
      }

      final agoraEfetivo = agora ?? DateTime.now();
      final nomeArquivo = 'mentall-backup-${_carimbo(agoraEfetivo)}.json';
      final local = diretorio ?? configuracoes.backupLocal;

      final caminho =
          await salvarBackupArquivo(conteudo, nomeArquivo, diretorio: local);
      if (caminho == null) return null;

      await configuracoes.setUltimoBackupEm(agoraEfetivo);
      return caminho;
    } catch (_) {
      return null;
    }
  }

  /// Verifica se está na hora e executa em background. Retorna o caminho se
  /// rodou, ou `null` se não era a vez / falhou.
  Future<String?> verificarEExecutar({DateTime? agora}) async {
    final efetivo = agora ?? DateTime.now();
    if (!deveExecutarAgora(
      frequencia: configuracoes.backupFrequencia,
      ultimoBackup: configuracoes.ultimoBackupEm,
      agora: efetivo,
    )) {
      return null;
    }
    return executar(agora: efetivo);
  }

  String _carimbo(DateTime data) {
    final d = data.day.toString().padLeft(2, '0');
    final m = data.month.toString().padLeft(2, '0');
    final a = data.year;
    final h = data.hour.toString().padLeft(2, '0');
    final min = data.minute.toString().padLeft(2, '0');
    return '$a$m$d-$h$min';
  }
}
