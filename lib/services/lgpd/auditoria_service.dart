import 'package:hive_ce/hive.dart';

import '../../models/lgpd/registro_auditoria.dart';
import '../logger.dart';

class AuditoriaService {
  static const String _boxName = 'auditoria';

  AuditoriaService();

  Box<RegistroAuditoria> get _box => Hive.box<RegistroAuditoria>(_boxName);

  Future<void> registrar({
    required String tipoEvento,
    required String descricao,
    String pacienteId = '',
  }) async {
    try {
      final registro = RegistroAuditoria(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        tipoEvento: tipoEvento,
        descricao: descricao,
        dataHora: DateTime.now(),
        pacienteId: pacienteId,
      );

      await _box.add(registro);
      Log.auditoria('$tipoEvento: $descricao', contexto: 'Auditoria');
    } catch (e) {
      Log.erro(e, contexto: 'AuditoriaService.registrar');
    }
  }

  List<RegistroAuditoria> listar({int limite = 200}) {
    final todos = _box.values.toList()
      ..sort((a, b) => b.dataHora.compareTo(a.dataHora));

    return todos.take(limite).toList();
  }

  List<RegistroAuditoria> listarPorPaciente(String pacienteId, {int limite = 100}) {
    final filtrados = _box.values
        .where((r) => r.pacienteId == pacienteId)
        .toList()
      ..sort((a, b) => b.dataHora.compareTo(a.dataHora));

    return filtrados.take(limite).toList();
  }

  Future<int> contar() async {
    return _box.length;
  }

  Stream<BoxEvent> observar() {
    return _box.watch();
  }
}
