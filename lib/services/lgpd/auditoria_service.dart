import 'package:hive_ce/hive.dart';

import '../../models/lgpd/registro_auditoria.dart';
import '../../services/encrypted_service_mixin.dart';
import '../../services/encryption_service.dart';
import '../logger.dart';

class AuditoriaService with EncryptedServiceMixin {
  static const String _boxName = 'auditoria';
  static const int _maxRegistros = 1000;

  @override
  final EncryptionService? encryption;

  AuditoriaService({this.encryption});

  Box<RegistroAuditoria> get _box => Hive.box<RegistroAuditoria>(_boxName);

  static String traduzirEvento(String tipoEvento) {
    final t = tipoEvento.toLowerCase();
    if (t.contains('agendad')) return 'Agendamento de consulta';
    if (t.contains('cadastrad')) return 'Cadastro de pessoa atendida no sistema';
    if (t.contains('sintese') || t.contains('síntese')) return 'Uso de IA para organizar anotações da sessão';
    if (t.contains('transcri')) return 'Conversão de áudio em texto';
    if (t.contains('gravacao') || t.contains('gravação') || t.contains('audio') || t.contains('áudio')) return 'Gravação de relato em áudio';
    if (t.contains('revis')) return 'Revisão da sessão pelo profissional';
    if (t.contains('registrad') || t.contains('sessao') || t.contains('sessão')) return 'Registro de sessão no prontuário';
    if (t.contains('contrato') || t.contains('acordo')) return 'Envio de acordo terapêutico';
    if (t.contains('arquivad')) return 'Arquivamento de registro';
    if (t.contains('restaurad')) return 'Restauração de registro';
    if (t.contains('export')) return 'Exportação de dados';
    if (t.contains('ia') || t.contains('processad')) return 'Uso de IA para organizar anotações';
    return tipoEvento;
  }

  String gerarRelatorioLeigo(List<RegistroAuditoria> registros) {
    if (registros.isEmpty) return 'Nenhum registro de atividade encontrado.';

    final buffer = StringBuffer();
    buffer.writeln('RELATÓRIO DE ATIVIDADE - MENTALL');
    buffer.writeln('Gerado em: ${_formatarDataCompleta(DateTime.now())}');
    buffer.writeln('Total de eventos registrados: ${registros.length}');
    buffer.writeln('');
    buffer.writeln('Este relatório descreve, em linguagem simples, todas as ações');
    buffer.writeln('realizadas no aplicativo MentAll que envolvem o prontuário.');
    buffer.writeln('');

    for (final r in registros) {
      final traducao = traduzirEvento(r.tipoEvento);
      buffer.writeln('• ${_formatarDataCompleta(r.dataHora)}');
      buffer.writeln('  $traducao');
      if (r.descricao.isNotEmpty) {
        buffer.writeln('  Detalhes: ${r.descricao}');
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }

  String _formatarDataCompleta(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');
    return '$dia/$mes/$ano às $hora:$minuto';
  }

  Future<void> registrar({
    required String tipoEvento,
    required String descricao,
    String pacienteId = '',
  }) async {
    try {
      final registro = RegistroAuditoria(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        tipoEvento: tipoEvento,
        descricao: encrypt(descricao),
        dataHora: DateTime.now(),
        pacienteId: pacienteId,
      );

      await _box.add(registro);
      await _trimExcesso();
      Log.auditoria('$tipoEvento: $descricao', contexto: 'Auditoria');
    } catch (e) {
      Log.erro(e, contexto: 'AuditoriaService.registrar');
    }
  }

  Future<void> _trimExcesso() async {
    if (_box.length <= _maxRegistros) return;
    final todos = _box.values.toList()
      ..sort((a, b) => a.dataHora.compareTo(b.dataHora));
    final excedente = todos.length - _maxRegistros;
    for (var i = 0; i < excedente; i++) {
      await todos[i].delete();
    }
  }

  List<RegistroAuditoria> listar({int limite = 200}) {
    final todos = _box.values.toList()
      ..sort((a, b) => b.dataHora.compareTo(a.dataHora));

    final resultado = todos.take(limite).toList();
    for (final r in resultado) {
      r.descricao = decrypt(r.descricao);
    }
    return resultado;
  }

  List<RegistroAuditoria> listarPorPaciente(String pacienteId, {int limite = 100}) {
    final filtrados = _box.values
        .where((r) => r.pacienteId == pacienteId)
        .toList()
      ..sort((a, b) => b.dataHora.compareTo(a.dataHora));

    final resultado = filtrados.take(limite).toList();
    for (final r in resultado) {
      r.descricao = decrypt(r.descricao);
    }
    return resultado;
  }

  Future<int> contar() async {
    return _box.length;
  }

  Stream<BoxEvent> observar() {
    return _box.watch();
  }
}
