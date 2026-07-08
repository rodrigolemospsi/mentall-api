import 'package:hive_ce/hive.dart';

import '../../models/lgpd/registro_auditoria.dart';
import '../logger.dart';

class AuditoriaService {
  static const String _boxName = 'auditoria';
  late final Box<RegistroAuditoria> _box;

  bool _inicializado = false;

  AuditoriaService();

  Future<void> inicializar() async {
    if (_inicializado) return;
    _box = await Hive.openBox<RegistroAuditoria>(_boxName);
    _inicializado = true;
  }

  Future<void> registrar({
    required String tipoEvento,
    required String descricao,
    String pacienteId = '',
  }) async {
    if (!_inicializado) return;

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
    if (!_inicializado) return [];

    final todos = _box.values.toList()
      ..sort((a, b) => b.dataHora.compareTo(a.dataHora));

    return todos.take(limite).toList();
  }

  List<RegistroAuditoria> listarPorPaciente(String pacienteId, {int limite = 100}) {
    if (!_inicializado) return [];

    final filtrados = _box.values
        .where((r) => r.pacienteId == pacienteId)
        .toList()
      ..sort((a, b) => b.dataHora.compareTo(a.dataHora));

    return filtrados.take(limite).toList();
  }

  Future<int> contar() async {
    if (!_inicializado) return 0;
    return _box.length;
  }
}
