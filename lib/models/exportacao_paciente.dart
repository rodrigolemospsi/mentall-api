import 'anamnese_enviada.dart';
import 'contrato_terapeutico.dart';
import 'paciente.dart';
import 'sessao.dart';

/// Dados de um paciente para a exportação completa em PDF (Fase 5Q).
///
/// Reúne tudo o que o "Exportar tudo" precisa imprimir: dados cadastrais,
/// sessões (ativas), contrato e anamnese. O PDF é legível/arquivável; NÃO
/// substitui o backup cifrado, que é o único formato restaurável.
class ExportacaoPaciente {
  final Paciente paciente;
  final List<Sessao> sessoes;
  final ContratoTerapeutico? contrato;
  final AnamneseEnviada? anamnese;

  const ExportacaoPaciente({
    required this.paciente,
    this.sessoes = const <Sessao>[],
    this.contrato,
    this.anamnese,
  });
}
