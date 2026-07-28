part of 'sessao_form_page.dart';

extension _SessaoFormStateIa on _SessaoFormPageState {

// ============================================================
// HELPERS DE PREENCHIMENTO
// ============================================================

void _preencherController({
  required TextEditingController controller,
  required String texto,
}) {
  final textoLimpo = texto.trim();

  controller.value = TextEditingValue(
    text: textoLimpo,
    selection: TextSelection.collapsed(
      offset: textoLimpo.length,
    ),
  );
}

// ============================================================
// SÍNTESE COM IA
// ============================================================

Future<void> _gerarSinteseComIa() async {
  if (_existeAcaoEmAndamento) return;

  final relato = _relatoPosSessaoController.text.trim();
  final transcricao = _transcricaoRelatoController.text.trim();

  if (relato.isEmpty && transcricao.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Revise ou escreva a transcrição antes de solicitar a síntese com IA.',
        ),
      ),
    );
    return;
  }

  try {
    if (_reproduzindoAudio) {
      await _audioPlayer.stop();
    }

    _gerandoSinteseIa = true;
    _reproduzindoAudio = false;
    _statusProcessamento = 'ia_processando';
    _erroProcessamentoIa = '';
    _revisadoPeloProfissional = false;
    _triggerRebuild();
    ref.read(erroAudioProvider.notifier).state = '';

    final resultado = await _iaClinicaService.gerarSinteseClinica(
      sessaoId: _sessaoId,
      numeroSessao: _numeroSessao,
      nomePessoaAtendida: _nomePessoaAtendidaExibicao,
      termoPessoaAtendida: _termoSingular,
      abordagemClinica: _abordagemClinica,
      transcricaoRelato: transcricao,
      relatoManual: relato,
      temaPrincipal: '',
    );

    if (!mounted) return;

    if (resultado.sucesso) {
      _preencherController(
        controller: _relatoPosSessaoController,
        texto: resultado.relatoClinicoOrganizado,
      );

      final sintese = [
        if (resultado.eventosImportantes.isNotEmpty) resultado.eventosImportantes,
        if (resultado.evolucaoClinica.isNotEmpty) resultado.evolucaoClinica,
        if (resultado.observacoes.isNotEmpty) resultado.observacoes,
      ].join('\n\n');
      _preencherController(controller: _sinteseController, texto: sintese);

      final formulacao = [
        if (resultado.pensamentosAutomaticos.isNotEmpty) resultado.pensamentosAutomaticos,
        if (resultado.emocoes.isNotEmpty) resultado.emocoes,
        if (resultado.comportamentos.isNotEmpty) resultado.comportamentos,
      ].join('\n\n');
      _preencherController(controller: _formulacaoController, texto: formulacao);

      final intervencoes = [
        if (resultado.intervencoes.isNotEmpty) resultado.intervencoes,
        if (resultado.tecnicas.isNotEmpty) resultado.tecnicas,
      ].join('\n\n');
      _preencherController(controller: _intervencoesController, texto: intervencoes);

      _preencherController(
        controller: _apontamentosController,
        texto: resultado.apontamentosCopiloto,
      );

      _artigosSugeridos = ref.read(configuracoesServiceProvider).sugerirArtigos
          ? resultado.artigosSugeridos
          : '';

      _gerandoSinteseIa = false;
      _geradoComIa = true;
      _dataProcessamentoIa = DateTime.now();
      _statusProcessamento = 'ia_processada';
      _revisadoPeloProfissional = false;
      _erroProcessamentoIa = '';
      _avisoInvalidacaoTranscricaoExibido = false;
      _triggerRebuild();

      _registrarAuditoria('Sintese gerada por IA', 'IA gerou sintese clinica - sessao $_numeroSessao');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Síntese clínica e campos estruturados gerados para revisão.',
          ),
        ),
      );

      return;
    }

    _gerandoSinteseIa = false;
    _statusProcessamento =
        _possuiTranscricaoRelato ? 'transcrito' : 'manual';
    _erroProcessamentoIa = resultado.erro;
    _triggerRebuild();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível gerar a síntese clínica.'),
      ),
    );
  } catch (erro) {
    if (!mounted) return;

    _gerandoSinteseIa = false;
    _statusProcessamento =
        _possuiTranscricaoRelato ? 'transcrito' : 'manual';
    _erroProcessamentoIa =
        'Não foi possível gerar a síntese clínica. Detalhes: $erro';
    _triggerRebuild();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível gerar a síntese clínica.'),
      ),
    );
  }
}

// ============================================================
// REVISÃO
// ============================================================

void _marcarComoRevisado() {
  _revisadoPeloProfissional = true;
  _statusProcessamento = 'revisado';
  _triggerRebuild();
  ref.read(erroAudioProvider.notifier).state = '';

  _registrarAuditoria('Revisao profissional', 'Sessao $_numeroSessao marcada como revisada');

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Sessão marcada como revisada pelo profissional.'),
    ),
  );
}

void _limparErroProcessamento() {
  _erroProcessamentoIa = '';

  if (_statusProcessamento == 'erro') {
    _statusProcessamento =
        _origemRelato == 'audio' ? 'audio_gravado' : 'manual';
  }
  _triggerRebuild();
}

void _limparErroAudio() {
  ref.read(erroAudioProvider.notifier).state = '';
}

// ============================================================
// SALVAR SESSÃO
// ============================================================

Future<void> _salvarSessao() async {
  if (ref.read(_salvandoProvider)) return;

  if (_existeAcaoEmAndamento) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Finalize a ação em andamento antes de salvar a sessão.',
        ),
      ),
    );
    return;
  }

  if (_reproduzindoAudio) {
    await _audioPlayer.stop();

    if (!mounted) return;

    _reproduzindoAudio = false;
    _triggerRebuild();
  }
  ref.read(_salvandoProvider.notifier).state = true;

  try {
    final dataSessao = ref.read(_dataSessaoProvider);

    if (_editando) {
      final sessao = widget.sessaoExistente!;

      sessao.numeroSessao = _numeroSessao;
      sessao.data = dataSessao;
      sessao.temaPrincipal = '';
      sessao.relatoPosSessao = _relatoPosSessaoController.text.trim();
      sessao.transcricaoRelato = _transcricaoRelatoController.text.trim();
      sessao.eventosImportantes = _sinteseController.text.trim();
      sessao.evolucaoClinica = '';
      sessao.observacoes = '';
      sessao.pensamentosAutomaticos = _formulacaoController.text.trim();
      sessao.emocoes = '';
      sessao.comportamentos = '';
      sessao.intervencoes = _intervencoesController.text.trim();
      sessao.tecnicasTcc = '';
      sessao.tarefaCasa = '';
      sessao.planoProximaSessao = '';
      sessao.apontamentosCopiloto = _apontamentosController.text.trim();

      sessao.audioRelatoPath = _audioRelatoPath;
      sessao.audioRelatoBase64 = _audioRelatoBase64;
      sessao.dataProcessamentoIa = _dataProcessamentoIa;
      sessao.geradoComIa = _geradoComIa;
      sessao.statusProcessamento = _statusProcessamento;
      sessao.audioMantido = _audioMantido;
      sessao.revisadoPeloProfissional = _revisadoPeloProfissional;
      sessao.erroProcessamentoIa = _erroProcessamentoIa;
      sessao.origemRelato = _origemRelato;
      sessao.artigosSugeridos = _artigosSugeridos;

      await _sessaoService.atualizarSessao(sessao);
      _modoEdicao = false;
    } else {
      final dataSessao = ref.read(_dataSessaoProvider);

      final novaSessao = Sessao(
        id: _sessaoId,
        pacienteId: widget.paciente.id,
        numeroSessao: _numeroSessao,
        data: dataSessao,
        temaPrincipal: '',
        relatoPosSessao: _relatoPosSessaoController.text.trim(),
        transcricaoRelato: _transcricaoRelatoController.text.trim(),
        eventosImportantes: _sinteseController.text.trim(),
        evolucaoClinica: '',
        observacoes: '',
        pensamentosAutomaticos: _formulacaoController.text.trim(),
        emocoes: '',
        comportamentos: '',
        intervencoes: _intervencoesController.text.trim(),
        tecnicasTcc: '',
        tarefaCasa: '',
        planoProximaSessao: '',
        apontamentosCopiloto: _apontamentosController.text.trim(),
        audioRelatoPath: _audioRelatoPath,
        audioRelatoBase64: _audioRelatoBase64,
        dataProcessamentoIa: _dataProcessamentoIa,
        geradoComIa: _geradoComIa,
        statusProcessamento: _statusProcessamento,
        audioMantido: _audioMantido,
        revisadoPeloProfissional: _revisadoPeloProfissional,
        erroProcessamentoIa: _erroProcessamentoIa,
        origemRelato: _origemRelato,
        artigosSugeridos: _artigosSugeridos,
      );

      await _sessaoService.adicionarSessao(novaSessao);
      _registrarAuditoria(
        'Sessão registrada',
        '${widget.paciente.nome} - sessão $_numeroSessao',
      );
      _modoEdicao = false;
    }

    if (!mounted) return;

    Navigator.pop(context);
  } catch (erro) {
    Log.erro(erro, contexto: 'sessao_form_page:salvarSessao');
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível salvar a sessão. Tente novamente.'),
      ),
    );
  } finally {
    if (mounted) {
      ref.read(_salvandoProvider.notifier).state = false;
    }
  }
}

}
