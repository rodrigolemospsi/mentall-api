part of 'sessao_form_page.dart';

extension _SessaoFormStateAudio on _SessaoFormPageState {

// ============================================================
// CONTADORES DE GRAVAÇÃO
// ============================================================

void _iniciarContadorGravacao() {
  _timerGravacao?.cancel();

  ref.read(duracaoGravacaoProvider.notifier).state = Duration.zero;

  _timerGravacao = Timer.periodic(
    const Duration(seconds: 1),
    (_) {
      if (!mounted) return;

      final novaDuracao =
          ref.read(duracaoGravacaoProvider) + const Duration(seconds: 1);
      ref.read(duracaoGravacaoProvider.notifier).state = novaDuracao;
      _triggerRebuild();

      if (novaDuracao >= _SessaoFormPageState._duracaoMaximaAudio) {
        _pararGravacaoRelato();
      }
    },
  );
}

void _pausarContadorGravacao() {
  _timerGravacao?.cancel();
  _timerGravacao = null;
}

void _retomarContadorGravacao() {
  _timerGravacao?.cancel();

  _timerGravacao = Timer.periodic(
    const Duration(seconds: 1),
    (_) {
      if (!mounted) return;

      final novaDuracao =
          ref.read(duracaoGravacaoProvider) + const Duration(seconds: 1);
      ref.read(duracaoGravacaoProvider.notifier).state = novaDuracao;
      _triggerRebuild();

      if (novaDuracao >= _SessaoFormPageState._duracaoMaximaAudio) {
        _pararGravacaoRelato();
      }
    },
  );
}

void _pararContadorGravacao() {
  _timerGravacao?.cancel();
  _timerGravacao = null;
}

// ============================================================
// HELPERS DE ÁUDIO
// ============================================================

String _normalizarAudioBase64(String valor) {
  final texto = valor.trim();

  if (texto.startsWith('data:') && texto.contains(',')) {
    return texto.split(',').last.trim();
  }

  return texto;
}

Source? _criarFonteAudioPorCaminho(String caminhoAudio) {
  final caminho = caminhoAudio.trim();

  if (caminho.isEmpty) {
    return null;
  }

  if (caminho.startsWith('http') || caminho.startsWith('blob:')) {
    return UrlSource(caminho);
  }

  return DeviceFileSource(caminho);
}

Source? _criarFonteAudioBase64() {
  final base64Audio = _normalizarAudioBase64(ref.read(audioRelatoBase64Provider));

  if (base64Audio.isEmpty) {
    return null;
  }

  return BytesSource(base64Decode(base64Audio));
}

// ============================================================
// AÇÕES DE GRAVAÇÃO
// ============================================================

Future<void> _iniciarGravacaoRelato() async {
  if (_existeAcaoEmAndamento) return;

  try {
    if (ref.read(reproduzindoAudioProvider)) {
      await _audioPlayer.stop();
    }

    await _audioRelatoService.iniciarGravacao(
      sessaoId: _sessaoId,
    );

    _iniciarContadorGravacao();

    if (!mounted) return;

    _origemRelato = 'audio';
    ref.read(erroAudioProvider.notifier).state = '';
    ref.read(gravandoAudioProvider.notifier).state = true;
    ref.read(audioPausadoProvider.notifier).state = false;
    ref.read(reproduzindoAudioProvider.notifier).state = false;
    _triggerRebuild();

    _registrarAuditoria('Gravacao de audio', 'Inicio da gravacao do relato - sessao $_numeroSessao');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _possuiAudioRelato
              ? 'Nova gravação iniciada. O áudio anterior só será substituído ao finalizar.'
              : 'Gravação iniciada. Fale seu relato pós-sessão.',
        ),
      ),
    );
  } catch (erro) {
    _pararContadorGravacao();

    if (!mounted) return;

    ref.read(erroAudioProvider.notifier).state =
        'Não foi possível iniciar a gravação. Detalhes: $erro';
    ref.read(gravandoAudioProvider.notifier).state = false;
    ref.read(audioPausadoProvider.notifier).state = false;
    ref.read(reproduzindoAudioProvider.notifier).state = false;
    _triggerRebuild();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível iniciar a gravação. Verifique a permissão do microfone.',
        ),
      ),
    );
  }
}

Future<void> _pausarGravacaoRelato() async {
  if (!ref.read(gravandoAudioProvider) || ref.read(audioPausadoProvider)) return;

  try {
    await _audioRelatoService.pausarGravacao();
    _pausarContadorGravacao();

    if (!mounted) return;

    ref.read(audioPausadoProvider.notifier).state = true;
    ref.read(erroAudioProvider.notifier).state = '';
    _triggerRebuild();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gravação pausada.'),
      ),
    );
  } catch (erro) {
    if (!mounted) return;

    ref.read(erroAudioProvider.notifier).state =
        'Não foi possível pausar a gravação. Detalhes: $erro';
    _triggerRebuild();
  }
}

Future<void> _retomarGravacaoRelato() async {
  if (!ref.read(gravandoAudioProvider) || !ref.read(audioPausadoProvider)) return;

  try {
    await _audioRelatoService.retomarGravacao();
    _retomarContadorGravacao();

    if (!mounted) return;

    ref.read(audioPausadoProvider.notifier).state = false;
    ref.read(erroAudioProvider.notifier).state = '';
    _triggerRebuild();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gravação retomada.'),
      ),
    );
  } catch (erro) {
    if (!mounted) return;

    ref.read(erroAudioProvider.notifier).state =
        'Não foi possível retomar a gravação. Detalhes: $erro';
    _triggerRebuild();
  }
}

Future<void> _pararGravacaoRelato() async {
  if (!ref.read(gravandoAudioProvider)) return;

  try {
    final caminho = await _audioRelatoService.pararGravacao();

    String audioBase64 = '';

    try {
      audioBase64 = await _audioRelatoService.obterAudioAtualBase64();
    } catch (erroBase64) {
      audioBase64 = '';

      if (mounted) {
        ref.read(erroAudioProvider.notifier).state =
            'O áudio foi gravado, mas não foi possível criar o backup interno em Base64. Detalhes: $erroBase64';
      }
    }

    _pararContadorGravacao();

    if (!mounted) return;

    if (caminho != null && caminho.trim().isNotEmpty) {
      ref.read(audioRelatoPathProvider.notifier).state = caminho.trim();
    }

    ref.read(audioRelatoBase64Provider.notifier).state = audioBase64.trim();

    _origemRelato = 'audio';
    _statusProcessamento = 'audio_gravado';
    _audioMantido = true;

    _revisadoPeloProfissional = false;
    _geradoComIa = false;
    _dataProcessamentoIa = null;
    _erroProcessamentoIa = '';

    if (ref.read(audioRelatoBase64Provider).trim().isNotEmpty) {
      ref.read(erroAudioProvider.notifier).state = '';
    }

    _atualizarTranscricaoProgramaticamente('');
    _limparCamposGeradosPelaIa();

    ref.read(gravandoAudioProvider.notifier).state = false;
    ref.read(audioPausadoProvider.notifier).state = false;
    _triggerRebuild();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _possuiAudioRelatoBase64
              ? 'Gravação finalizada e salva com backup interno em Base64.'
              : 'Gravação finalizada e vinculada à sessão. O backup Base64 não foi gerado.',
        ),
      ),
    );
  } catch (erro) {
    _pararContadorGravacao();

    if (!mounted) return;

    ref.read(erroAudioProvider.notifier).state =
        'Não foi possível finalizar a gravação. Detalhes: $erro';
    ref.read(gravandoAudioProvider.notifier).state = false;
    ref.read(audioPausadoProvider.notifier).state = false;
    _triggerRebuild();
  }
}

Future<void> _cancelarGravacaoRelato() async {
  try {
    await _audioRelatoService.cancelarGravacao();
    _pararContadorGravacao();

    if (!mounted) return;

    ref.read(gravandoAudioProvider.notifier).state = false;
    ref.read(audioPausadoProvider.notifier).state = false;
    ref.read(duracaoGravacaoProvider.notifier).state = Duration.zero;
    ref.read(erroAudioProvider.notifier).state = '';

    if (!_possuiAudioRelato) {
      _origemRelato = 'manual';
      _statusProcessamento = 'manual';
      _audioMantido = false;
      _revisadoPeloProfissional = false;
    }

    _triggerRebuild();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gravação cancelada.'),
      ),
    );
  } catch (erro) {
    if (!mounted) return;

    ref.read(erroAudioProvider.notifier).state =
        'Não foi possível cancelar a gravação. Detalhes: $erro';
    _triggerRebuild();
  }
}

// ============================================================
// PLAYBACK DE ÁUDIO
// ============================================================

Future<void> _ouvirOuPararAudioRelato() async {
  if (!_possuiAudioRelato) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nenhum áudio foi gravado para esta sessão.'),
      ),
    );
    return;
  }

  if (_existeAcaoEmAndamento) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Finalize a ação atual antes de ouvir o áudio.'),
      ),
    );
    return;
  }

  try {
    if (ref.read(reproduzindoAudioProvider)) {
      await _audioPlayer.stop();

      if (!mounted) return;

      ref.read(reproduzindoAudioProvider.notifier).state = false;
      _triggerRebuild();

      return;
    }

    await _audioPlayer.stop();

    final caminhoAudio = ref.read(audioRelatoPathProvider).trim();

    Source? fonteAudio;

    final devePreferirBase64 =
        _possuiAudioRelatoBase64 &&
            (caminhoAudio.isEmpty || caminhoAudio.startsWith('blob:'));

    if (devePreferirBase64) {
      fonteAudio = _criarFonteAudioBase64();
    } else {
      fonteAudio = _criarFonteAudioPorCaminho(caminhoAudio) ??
          _criarFonteAudioBase64();
    }

    if (fonteAudio == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não há fonte de áudio disponível para reprodução.'),
        ),
      );
      return;
    }

    try {
      await _audioPlayer.play(fonteAudio);
    } catch (erro) {
      Log.erro(erro, contexto: 'sessao_form_page:reproduzirAudio');
      final fonteAlternativa = devePreferirBase64
          ? _criarFonteAudioPorCaminho(caminhoAudio)
          : _criarFonteAudioBase64();

      if (fonteAlternativa == null) {
        rethrow;
      }

      await _audioPlayer.play(fonteAlternativa);
    }

    if (!mounted) return;

    ref.read(reproduzindoAudioProvider.notifier).state = true;
    ref.read(erroAudioProvider.notifier).state = '';
    _triggerRebuild();
  } catch (erro) {
    if (!mounted) return;

    ref.read(reproduzindoAudioProvider.notifier).state = false;
    ref.read(erroAudioProvider.notifier).state =
        'Não foi possível reproduzir o áudio gravado. Detalhes: $erro';
    _triggerRebuild();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível reproduzir o áudio gravado.'),
      ),
    );
  }
}

Future<void> _removerAudioRelato() async {
  if (!_possuiAudioRelato || _existeAcaoEmAndamento) return;

  final confirmar = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Remover áudio?'),
        content: const Text(
          'O áudio gravado será desvinculado desta sessão. '
          'A transcrição e os apontamentos gerados a partir dele também serão limpos. '
          'A sessão permanecerá salva e poderá receber um novo relato.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remover áudio'),
          ),
        ],
      );
    },
  );

  if (!mounted || confirmar != true) return;

  try {
    if (ref.read(reproduzindoAudioProvider)) {
      await _audioPlayer.stop();
    }

    await _audioRelatoService.removerAudioAtual();

    if (!mounted) return;

    ref.read(audioRelatoPathProvider.notifier).state = '';
    ref.read(audioRelatoBase64Provider.notifier).state = '';
    _audioMantido = false;
    _origemRelato = 'manual';
    _statusProcessamento = 'manual';

    ref.read(reproduzindoAudioProvider.notifier).state = false;
    ref.read(gravandoAudioProvider.notifier).state = false;
    ref.read(audioPausadoProvider.notifier).state = false;
    _transcrevendoRelato = false;
    _gerandoSinteseIa = false;
    ref.read(duracaoGravacaoProvider.notifier).state = Duration.zero;

    _atualizarTranscricaoProgramaticamente('');
    _limparCamposGeradosPelaIa();

    _geradoComIa = false;
    _dataProcessamentoIa = null;
    _erroProcessamentoIa = '';
    ref.read(erroAudioProvider.notifier).state = '';
    _revisadoPeloProfissional = false;
    _triggerRebuild();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Áudio removido da sessão.'),
      ),
    );
  } catch (erro) {
    if (!mounted) return;

    ref.read(erroAudioProvider.notifier).state =
        'Não foi possível remover o áudio. Detalhes: $erro';
    _triggerRebuild();
  }
}

// ============================================================
// TRANSCRIÇÃO
// ============================================================

Future<void> _transcreverRelato() async {
  if (_existeAcaoEmAndamento) return;

  if (!_possuiAudioRelato) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Grave primeiro um relato para transcrever o áudio.'),
      ),
    );
    return;
  }

  try {
    if (_reproduzindoAudio) {
      await _audioPlayer.stop();
    }

    _transcrevendoRelato = true;
    _reproduzindoAudio = false;
    _statusProcessamento = 'transcrevendo';
    _erroProcessamentoIa = '';
    _revisadoPeloProfissional = false;
    _triggerRebuild();
    ref.read(erroAudioProvider.notifier).state = '';

    final resultado = await _transcricaoRelatoService.transcreverAudio(
      audioRelatoPath: _audioRelatoPath,
      audioRelatoBase64: _audioRelatoBase64,
      sessaoId: _sessaoId,
    );

    if (!mounted) return;

    if (resultado.sucesso) {
      final textoTranscrito = resultado.transcricao.trim();

      if (textoTranscrito.isEmpty) {
        _statusProcessamento = 'audio_gravado';
        _transcrevendoRelato = false;
        _erroProcessamentoIa =
            'O serviço de transcrição concluiu a operação, mas não retornou texto.';
        _triggerRebuild();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A transcrição não retornou nenhum texto.'),
          ),
        );

        return;
      }

      _atualizarTranscricaoProgramaticamente(textoTranscrito);

      _statusProcessamento = 'transcrito';
      _transcrevendoRelato = false;
      _revisadoPeloProfissional = false;
      _geradoComIa = false;
      _dataProcessamentoIa = null;
      _erroProcessamentoIa = '';
      _avisoInvalidacaoTranscricaoExibido = false;
      _triggerRebuild();

      _registrarAuditoria('Transcrição concluída', 'Transcrição do áudio realizada - sessão $_numeroSessao');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transcrição concluída e inserida no campo.'),
        ),
      );

      return;
    }

    _statusProcessamento = 'audio_gravado';
    _transcrevendoRelato = false;
    _erroProcessamentoIa = resultado.erro;
    _triggerRebuild();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível transcrever o relato.'),
      ),
    );
  } catch (erro) {
    if (!mounted) return;

    _statusProcessamento = 'audio_gravado';
    _transcrevendoRelato = false;
    _erroProcessamentoIa =
        'Não foi possível transcrever o relato. Detalhes: $erro';
    _triggerRebuild();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível transcrever o relato.'),
      ),
    );
  }
}

}
