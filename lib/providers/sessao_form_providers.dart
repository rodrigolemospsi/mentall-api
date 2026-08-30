import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Providers de estado da tela de sessão (`SessaoFormPage`).
///
/// Foram movidos do topo de `sessao_form_page.dart` para este arquivo com
/// nomes públicos (prefixo `sessao*`) para que as seções de UI extraídas
/// (financeiro, progresso, relato+IA) possam ler o estado sem callbacks,
/// seguindo o padrão já usado em `sessao_audio_controls.dart`.

/// Flag "salvando" do botão Salvar.
final sessaoSalvandoProvider = StateProvider<bool>((ref) => false);

/// Data/hora da sessão.
final sessaoDataProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Contador de rebuild manual (`_triggerRebuild`).
final sessaoFormRebuildProvider = StateProvider<int>((ref) => 0);

/// Status do fluxo ('manual', 'audio_gravado', 'transcrevendo', 'transcrito',
/// 'ia_processando', 'ia_processada', 'revisado').
final sessaoStatusProcessamentoProvider = StateProvider<String>(
  (ref) => 'manual',
);

/// Se o profissional marcou como revisado.
final sessaoRevisadoProvider = StateProvider<bool>((ref) => false);

/// Se a síntese IA foi gerada.
final sessaoGeradoComIaProvider = StateProvider<bool>((ref) => false);

/// Quando a IA processou.
final sessaoDataProcessamentoIaProvider = StateProvider<DateTime?>(
  (ref) => null,
);

/// Guarda p/ exibir SnackBar de invalidação de transcrição só 1x.
final sessaoAvisoInvalidacaoProvider = StateProvider<bool>((ref) => false);

/// Switch "Manter áudio salvo".
final sessaoAudioMantidoProvider = StateProvider<bool>((ref) => false);

/// Origem do relato: 'audio' ou 'manual'.
final sessaoOrigemRelatoProvider = StateProvider<String>((ref) => 'manual');

/// Modo edição (vs. bloqueado).
final sessaoModoEdicaoProvider = StateProvider<bool>((ref) => false);

/// Valor da sessão (financeiro).
final sessaoValorSessaoProvider = StateProvider<double>((ref) => 0.0);

/// Status do pagamento: 'pendente'/'pago'/'convenio'/'pacote'.
final sessaoStatusPagamentoProvider = StateProvider<String>(
  (ref) => 'pendente',
);

/// Data do pagamento.
final sessaoDataPagamentoProvider = StateProvider<DateTime?>((ref) => null);

/// Método de pagamento.
final sessaoMetodoPagamentoProvider = StateProvider<String>((ref) => '');

/// Sintomas da evolução (IA).
final sessaoProgressoSintomasProvider =
    StateProvider<List<Map<String, dynamic>>>((ref) => []);

/// Avaliação geral da evolução.
final sessaoProgressoGeralProvider = StateProvider<String>((ref) => '');

/// Tendência da evolução: 'estavel'/'melhora'/'piora'/'mista'.
final sessaoProgressoTendenciaProvider = StateProvider<String>(
  (ref) => 'estavel',
);

/// Spinner de geração de progresso.
final sessaoProgressoGerandoProvider = StateProvider<bool>((ref) => false);

/// Spinner de busca de artigos.
final sessaoBuscandoArtigosProvider = StateProvider<bool>((ref) => false);
