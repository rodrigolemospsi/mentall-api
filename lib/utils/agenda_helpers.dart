import '../models/compromisso.dart';

List<Compromisso> filtrarCompromissos(
  List<Compromisso> compromissos, {
  String tipo = 'todos',
  String modalidade = 'todas',
}) {
  return compromissos.where((c) {
    if (tipo != 'todos' && c.tipoEvento != tipo) return false;
    if (modalidade != 'todas' && c.modalidade != modalidade) return false;
    return true;
  }).toList();
}

Map<String, List<Compromisso>> agruparPorSala(List<Compromisso> compromissos) {
  final grupos = <String, List<Compromisso>>{};
  for (final c in compromissos) {
    final sala = c.sala.trim().isEmpty ? 'Sem sala' : c.sala.trim();
    grupos.putIfAbsent(sala, () => []).add(c);
  }
  return grupos;
}
