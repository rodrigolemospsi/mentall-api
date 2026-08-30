import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sessao.dart';
import '../providers/service_providers.dart';

/// Helpers de lógica pura da tela de sessão (`SessaoFormPage`).
///
/// Extraídos de `sessao_form_page.dart` (fase 3 do plano de refatoração) para
/// reduzir o tamanho do arquivo e permitir teste isolado da lógica de dados.

String concatenarSintese(Sessao s) {
  final partes = <String>[];
  if (s.eventosImportantes.trim().isNotEmpty) {
    partes.add(s.eventosImportantes.trim());
  }
  if (s.evolucaoClinica.trim().isNotEmpty) {
    partes.add(s.evolucaoClinica.trim());
  }
  if (s.observacoes.trim().isNotEmpty) {
    partes.add(s.observacoes.trim());
  }
  return partes.join('\n\n');
}

String concatenarFormulacao(Sessao s) {
  final partes = <String>[];
  if (s.pensamentosAutomaticos.trim().isNotEmpty) {
    partes.add(s.pensamentosAutomaticos.trim());
  }
  if (s.emocoes.trim().isNotEmpty) {
    partes.add(s.emocoes.trim());
  }
  if (s.comportamentos.trim().isNotEmpty) {
    partes.add(s.comportamentos.trim());
  }
  return partes.join('\n\n');
}

String formatarData(DateTime data) {
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  final ano = data.year.toString();

  return '$dia/$mes/$ano';
}

String formatarHorario(DateTime data) {
  final hora = data.hour.toString().padLeft(2, '0');
  final minuto = data.minute.toString().padLeft(2, '0');

  return '$hora:$minuto';
}

String nomeEscala(String id) {
  const nomes = {
    'phq9': 'PHQ-9 (Depressão)',
    'gad7': 'GAD-7 (Ansiedade)',
    'dass21': 'DASS-21',
  };
  return nomes[id] ?? id;
}

/// Objetivos terapêuticos da avaliação inicial do paciente (ou '').
String obterObjetivosTerapeuticos(WidgetRef ref, String pacienteId) {
  try {
    final avaliacao = ref
        .read(avaliacaoInicialServiceProvider)
        .obterPorPaciente(pacienteId);
    return avaliacao?.objetivosTerapeuticos ?? '';
  } catch (_) {
    return '';
  }
}

/// Queixa principal da avaliação inicial do paciente (ou '').
String obterQueixaPrincipal(WidgetRef ref, String pacienteId) {
  try {
    final avaliacao = ref
        .read(avaliacaoInicialServiceProvider)
        .obterPorPaciente(pacienteId);
    return avaliacao?.queixaPrincipal ?? '';
  } catch (_) {
    return '';
  }
}

/// Escalas recentes do paciente, agrupadas por escala com datas/pontuações.
List<Map<String, dynamic>> obterEscalasRecentes(
  WidgetRef ref,
  String pacienteId,
) {
  try {
    final escalas = ref
        .read(escalaServiceProvider)
        .listarPorPaciente(pacienteId);
    final agrupadas = <String, List<Map<String, dynamic>>>{};
    for (final e in escalas) {
      agrupadas.putIfAbsent(e.escalaId, () => []);
      agrupadas[e.escalaId]!.add({
        'data': e.dataAplicacao.toIso8601String().substring(0, 10),
        'pontuacao': e.pontuacao,
        'interpretacao': e.interpretacao,
      });
    }
    return agrupadas.entries
        .map((entry) => {'nome': nomeEscala(entry.key), 'datas': entry.value})
        .toList();
  } catch (_) {
    return [];
  }
}
