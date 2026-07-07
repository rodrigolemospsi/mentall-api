import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../config/configuracao_abordagem_clinica.dart';
import '../models/paciente.dart';
import '../models/sessao.dart';
import '../services/audio_relato_service.dart';
import '../services/ia_clinica_service.dart';
import '../services/logger.dart';
import '../services/pdf_export_service.dart';
import '../services/perfil_profissional_service.dart';
import '../services/sessao_service.dart';
import '../services/transcricao_relato_service.dart';
import '../widgets/campo_texto_widget.dart';
import '../widgets/secao_formulario.dart';
import '../widgets/status_processamento_card.dart';

class SessaoFormPage extends StatefulWidget {
  final Paciente paciente;
  final Sessao? sessaoExistente;

  const SessaoFormPage({
    super.key,
    required this.paciente,
    this.sessaoExistente,
  });

  @override
  State<SessaoFormPage> createState() => _SessaoFormPageState();
}

class _SessaoFormPageState extends State<SessaoFormPage> {
  final SessaoService _sessaoService = SessaoService();
  final PerfilProfissionalService _perfilService = PerfilProfissionalService();
  final AudioRelatoService _audioRelatoService = AudioRelatoService();
  final TranscricaoRelatoService _transcricaoRelatoService =
      TranscricaoRelatoService();
  final IaClinicaService _iaClinicaService = IaClinicaService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<void>? _audioPlayerCompleteSubscription;

  final TextEditingController _temaController = TextEditingController();
  final TextEditingController _relatoPosSessaoController =
      TextEditingController();
  final TextEditingController _transcricaoRelatoController =
      TextEditingController();
  final TextEditingController _eventosController = TextEditingController();
  final TextEditingController _pensamentosController = TextEditingController();
  final TextEditingController _emocoesController = TextEditingController();
  final TextEditingController _comportamentosController =
      TextEditingController();
  final TextEditingController _intervencoesController =
      TextEditingController();
  final TextEditingController _tecnicasController = TextEditingController();
  final TextEditingController _tarefaController = TextEditingController();
  final TextEditingController _evolucaoController = TextEditingController();
  final TextEditingController _planoController = TextEditingController();
  final TextEditingController _observacoesController = TextEditingController();
  final TextEditingController _apontamentosCopilotoController =
      TextEditingController();

  late String _sessaoId;
  late int _numeroSessao;
  late DateTime _dataSessao;

  double _humor = 5;
  bool _salvando = false;

  bool _gravandoAudio = false;
  bool _audioPausado = false;
  bool _reproduzindoAudio = false;
  bool _transcrevendoRelato = false;
  bool _gerandoSinteseIa = false;

  Timer? _timerGravacao;
  Duration _duracaoGravacao = Duration.zero;

  String _audioRelatoPath = '';
  String _audioRelatoBase64 = '';
  DateTime? _dataProcessamentoIa;
  bool _geradoComIa = false;
  String _statusProcessamento = 'manual';
  bool _audioMantido = false;
  bool _revisadoPeloProfissional = false;
  String _erroProcessamentoIa = '';
  String _erroAudio = '';
  String _origemRelato = 'manual';

  String _ultimaTranscricaoControlada = '';
  bool _alteracaoProgramaticaTranscricao = false;
  bool _avisoInvalidacaoTranscricaoExibido = false;

  bool get _editando => widget.sessaoExistente != null;

  bool get _existeAcaoEmAndamento {
    return _gravandoAudio || _transcrevendoRelato || _gerandoSinteseIa;
  }

  String get _termoSingular {
    final perfil = _perfilService.obterPerfil();
    return perfil?.termoSingular ?? 'paciente';
  }

  String get _termoSingularCapitalizado {
    final perfil = _perfilService.obterPerfil();
    return perfil?.termoSingularCapitalizado ?? 'Paciente';
  }

  bool get _termoFeminino {
    return _termoSingular == 'pessoa atendida';
  }

  String get _doOuDa {
    return _termoFeminino ? 'da' : 'do';
  }

  String get _abordagemClinica {
    final perfil = _perfilService.obterPerfil();
    final abordagem = perfil?.abordagemClinica.trim() ?? '';

    if (abordagem.isEmpty) {
      return 'Integrativa';
    }

    return abordagem;
  }

  ConfiguracaoAbordagemClinica get _configuracaoAbordagem {
    return ConfiguracaoAbordagemClinica.porNome(_abordagemClinica);
  }

  String get _nomePessoaAtendidaExibicao {
    final nomeLimpo = widget.paciente.nome.trim();

    if (nomeLimpo.isEmpty) {
      return _termoSingularCapitalizado;
    }

    return nomeLimpo;
  }

  bool get _possuiAudioRelato {
    return _audioRelatoPath.trim().isNotEmpty ||
        _audioRelatoBase64.trim().isNotEmpty;
  }

  bool get _possuiAudioRelatoBase64 {
    return _audioRelatoBase64.trim().isNotEmpty;
  }

  bool get _possuiTranscricaoRelato {
    return _transcricaoRelatoController.text.trim().isNotEmpty;
  }

  bool get _possuiErroProcessamentoIa {
    return _erroProcessamentoIa.trim().isNotEmpty;
  }

  bool get _possuiErroAudio {
    return _erroAudio.trim().isNotEmpty;
  }

  bool get _estaAguardandoRevisao {
    return _statusProcessamento == 'audio_gravado' ||
        _statusProcessamento == 'transcrevendo' ||
        _statusProcessamento == 'transcrito' ||
        _statusProcessamento == 'ia_processando' ||
        _statusProcessamento == 'ia_processada';
  }

  @override
  void initState() {
    super.initState();

    _audioPlayerCompleteSubscription = _audioPlayer.onPlayerComplete.listen(
      (_) {
        if (!mounted) return;

        setState(() {
          _reproduzindoAudio = false;
        });
      },
    );

    final sessao = widget.sessaoExistente;

    if (sessao != null) {
      _sessaoId = sessao.id;
      _numeroSessao = sessao.numeroSessao;
      _dataSessao = sessao.data;
      _humor = sessao.humor.toDouble();

      _temaController.text = sessao.temaPrincipal;
      _relatoPosSessaoController.text = sessao.relatoPosSessao;
      _transcricaoRelatoController.text = sessao.transcricaoRelato;
      _eventosController.text = sessao.eventosImportantes;
      _pensamentosController.text = sessao.pensamentosAutomaticos;
      _emocoesController.text = sessao.emocoes;
      _comportamentosController.text = sessao.comportamentos;
      _intervencoesController.text = sessao.intervencoes;
      _tecnicasController.text = sessao.tecnicasTcc;
      _tarefaController.text = sessao.tarefaCasa;
      _evolucaoController.text = sessao.evolucaoClinica;
      _planoController.text = sessao.planoProximaSessao;
      _observacoesController.text = sessao.observacoes;
      _apontamentosCopilotoController.text = sessao.apontamentosCopiloto;

      _audioRelatoPath = sessao.audioRelatoPath;
      _audioRelatoBase64 = sessao.audioRelatoBase64;
      _dataProcessamentoIa = sessao.dataProcessamentoIa;
      _geradoComIa = sessao.geradoComIa;
      _statusProcessamento = sessao.statusProcessamento;
      _audioMantido = sessao.audioMantido;
      _revisadoPeloProfissional = sessao.revisadoPeloProfissional;
      _erroProcessamentoIa = sessao.erroProcessamentoIa;
      _origemRelato = sessao.origemRelato;
    } else {
      _sessaoId = DateTime.now().millisecondsSinceEpoch.toString();
      _numeroSessao = _sessaoService.proximoNumeroSessao(widget.paciente.id);
      _dataSessao = DateTime.now();
    }

    _ultimaTranscricaoControlada = _transcricaoRelatoController.text;
    _transcricaoRelatoController.addListener(_aoAlterarTranscricaoRelato);
  }

  @override
  void dispose() {
    _transcricaoRelatoController.removeListener(_aoAlterarTranscricaoRelato);

    _temaController.dispose();
    _relatoPosSessaoController.dispose();
    _transcricaoRelatoController.dispose();
    _eventosController.dispose();
    _pensamentosController.dispose();
    _emocoesController.dispose();
    _comportamentosController.dispose();
    _intervencoesController.dispose();
    _tecnicasController.dispose();
    _tarefaController.dispose();
    _evolucaoController.dispose();
    _planoController.dispose();
    _observacoesController.dispose();
    _apontamentosCopilotoController.dispose();

    _timerGravacao?.cancel();
    _audioPlayerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    _audioRelatoService.dispose();

    super.dispose();
  }

  void _aoAlterarTranscricaoRelato() {
    if (_alteracaoProgramaticaTranscricao) {
      _ultimaTranscricaoControlada = _transcricaoRelatoController.text;
      return;
    }

    final transcricaoAtual = _transcricaoRelatoController.text;

    if (transcricaoAtual == _ultimaTranscricaoControlada) {
      return;
    }

    _ultimaTranscricaoControlada = transcricaoAtual;

    final precisaInvalidar = _geradoComIa || _revisadoPeloProfissional;

    if (!precisaInvalidar) {
      return;
    }

    setState(() {
      _invalidarIaERevisaoPorAlteracaoDaTranscricao();
    });

    if (!_avisoInvalidacaoTranscricaoExibido && mounted) {
      _avisoInvalidacaoTranscricaoExibido = true;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A transcrição foi alterada. A síntese por IA e a revisão profissional foram invalidadas.',
          ),
        ),
      );
    }
  }

  void _invalidarIaERevisaoPorAlteracaoDaTranscricao() {
    final haviaConteudoGeradoComIa = _geradoComIa;

    _geradoComIa = false;
    _revisadoPeloProfissional = false;
    _dataProcessamentoIa = null;
    _erroProcessamentoIa = '';

    if (_transcricaoRelatoController.text.trim().isNotEmpty) {
      _statusProcessamento = 'transcrito';
      _origemRelato = _possuiAudioRelato ? 'audio' : 'manual';
    } else if (_possuiAudioRelato) {
      _statusProcessamento = 'audio_gravado';
      _origemRelato = 'audio';
    } else {
      _statusProcessamento = 'manual';
      _origemRelato = 'manual';
    }

    if (haviaConteudoGeradoComIa) {
      _limparCamposGeradosPelaIa();
    }
  }

  void _atualizarTranscricaoProgramaticamente(String texto) {
    final textoLimpo = texto.trim();

    _alteracaoProgramaticaTranscricao = true;

    try {
      _transcricaoRelatoController.value = TextEditingValue(
        text: textoLimpo,
        selection: TextSelection.collapsed(
          offset: textoLimpo.length,
        ),
      );

      _ultimaTranscricaoControlada = textoLimpo;
    } finally {
      _alteracaoProgramaticaTranscricao = false;
    }
  }

  void _limparCamposGeradosPelaIa() {
    _relatoPosSessaoController.clear();
    _apontamentosCopilotoController.clear();

    _eventosController.clear();
    _pensamentosController.clear();
    _emocoesController.clear();
    _comportamentosController.clear();
    _intervencoesController.clear();
    _tecnicasController.clear();
    _tarefaController.clear();
    _evolucaoController.clear();
    _planoController.clear();
    _observacoesController.clear();
  }

  void _iniciarContadorGravacao() {
    _timerGravacao?.cancel();

    setState(() {
      _duracaoGravacao = Duration.zero;
    });

    _timerGravacao = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;

        setState(() {
          _duracaoGravacao += const Duration(seconds: 1);
        });
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

        setState(() {
          _duracaoGravacao += const Duration(seconds: 1);
        });
      },
    );
  }

  void _pararContadorGravacao() {
    _timerGravacao?.cancel();
    _timerGravacao = null;
  }

  String _formatarDuracaoGravacao(Duration duracao) {
    final minutos = duracao.inMinutes.remainder(60).toString().padLeft(2, '0');
    final segundos = duracao.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$minutos:$segundos';
  }

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
    final base64Audio = _normalizarAudioBase64(_audioRelatoBase64);

    if (base64Audio.isEmpty) {
      return null;
    }

    return BytesSource(base64Decode(base64Audio));
  }

  Future<void> _selecionarData() async {
    final dataEscolhida = await showDatePicker(
      context: context,
      initialDate: _dataSessao,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (!mounted || dataEscolhida == null) return;

    setState(() {
      _dataSessao = DateTime(
        dataEscolhida.year,
        dataEscolhida.month,
        dataEscolhida.day,
        _dataSessao.hour,
        _dataSessao.minute,
      );
    });
  }

  Future<void> _selecionarHorario() async {
    final horarioAtual = TimeOfDay(
      hour: _dataSessao.hour,
      minute: _dataSessao.minute,
    );

    final horarioEscolhido = await showTimePicker(
      context: context,
      initialTime: horarioAtual,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: true,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (!mounted || horarioEscolhido == null) return;

    setState(() {
      _dataSessao = DateTime(
        _dataSessao.year,
        _dataSessao.month,
        _dataSessao.day,
        horarioEscolhido.hour,
        horarioEscolhido.minute,
      );
    });
  }

  Future<void> _iniciarGravacaoRelato() async {
    if (_existeAcaoEmAndamento) return;

    try {
      if (_reproduzindoAudio) {
        await _audioPlayer.stop();
      }

      await _audioRelatoService.iniciarGravacao(
        sessaoId: _sessaoId,
      );

      _iniciarContadorGravacao();

      if (!mounted) return;

      setState(() {
        _origemRelato = 'audio';
        _erroAudio = '';
        _gravandoAudio = true;
        _audioPausado = false;
        _reproduzindoAudio = false;
      });

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

      setState(() {
        _erroAudio = 'Não foi possível iniciar a gravação. Detalhes: $erro';
        _gravandoAudio = false;
        _audioPausado = false;
        _reproduzindoAudio = false;
      });

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
    if (!_gravandoAudio || _audioPausado) return;

    try {
      await _audioRelatoService.pausarGravacao();
      _pausarContadorGravacao();

      if (!mounted) return;

      setState(() {
        _audioPausado = true;
        _erroAudio = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gravação pausada.'),
        ),
      );
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        _erroAudio = 'Não foi possível pausar a gravação. Detalhes: $erro';
      });
    }
  }

  Future<void> _retomarGravacaoRelato() async {
    if (!_gravandoAudio || !_audioPausado) return;

    try {
      await _audioRelatoService.retomarGravacao();
      _retomarContadorGravacao();

      if (!mounted) return;

      setState(() {
        _audioPausado = false;
        _erroAudio = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gravação retomada.'),
        ),
      );
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        _erroAudio = 'Não foi possível retomar a gravação. Detalhes: $erro';
      });
    }
  }

  Future<void> _pararGravacaoRelato() async {
  if (!_gravandoAudio) return;

  try {
    final caminho = await _audioRelatoService.pararGravacao();

    String audioBase64 = '';

    try {
      audioBase64 = await _audioRelatoService.obterAudioAtualBase64();
    } catch (erroBase64) {
      audioBase64 = '';

      if (mounted) {
        setState(() {
          _erroAudio =
              'O áudio foi gravado, mas não foi possível criar o backup interno em Base64. Detalhes: $erroBase64';
        });
      }
    }

    _pararContadorGravacao();

    if (!mounted) return;

    setState(() {
      if (caminho != null && caminho.trim().isNotEmpty) {
        _audioRelatoPath = caminho.trim();
      }

      _audioRelatoBase64 = audioBase64.trim();

      _origemRelato = 'audio';
      _statusProcessamento = 'audio_gravado';
      _audioMantido = true;

      _revisadoPeloProfissional = false;
      _geradoComIa = false;
      _dataProcessamentoIa = null;
      _erroProcessamentoIa = '';

      if (_audioRelatoBase64.trim().isNotEmpty) {
        _erroAudio = '';
      }

      _atualizarTranscricaoProgramaticamente('');
      _limparCamposGeradosPelaIa();

      _gravandoAudio = false;
      _audioPausado = false;
    });

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

    setState(() {
      _erroAudio = 'Não foi possível finalizar a gravação. Detalhes: $erro';
      _gravandoAudio = false;
      _audioPausado = false;
    });
  }
}   

  Future<void> _cancelarGravacaoRelato() async {
    try {
      await _audioRelatoService.cancelarGravacao();
      _pararContadorGravacao();

      if (!mounted) return;

      setState(() {
        _gravandoAudio = false;
        _audioPausado = false;
        _duracaoGravacao = Duration.zero;
        _erroAudio = '';

        if (!_possuiAudioRelato) {
          _origemRelato = 'manual';
          _statusProcessamento = 'manual';
          _audioMantido = false;
          _revisadoPeloProfissional = false;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gravação cancelada.'),
        ),
      );
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        _erroAudio = 'Não foi possível cancelar a gravação. Detalhes: $erro';
      });
    }
  }

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
      if (_reproduzindoAudio) {
        await _audioPlayer.stop();

        if (!mounted) return;

        setState(() {
          _reproduzindoAudio = false;
        });

        return;
      }

      await _audioPlayer.stop();

      final caminhoAudio = _audioRelatoPath.trim();

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

      setState(() {
        _reproduzindoAudio = true;
        _erroAudio = '';
      });
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        _reproduzindoAudio = false;
        _erroAudio =
            'Não foi possível reproduzir o áudio gravado. Detalhes: $erro';
      });

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
      if (_reproduzindoAudio) {
        await _audioPlayer.stop();
      }

      await _audioRelatoService.removerAudioAtual();

      if (!mounted) return;

      setState(() {
        _audioRelatoPath = '';
        _audioRelatoBase64 = '';
        _audioMantido = false;
        _origemRelato = 'manual';
        _statusProcessamento = 'manual';

        _reproduzindoAudio = false;
        _gravandoAudio = false;
        _audioPausado = false;
        _transcrevendoRelato = false;
        _gerandoSinteseIa = false;
        _duracaoGravacao = Duration.zero;

        _atualizarTranscricaoProgramaticamente('');
        _limparCamposGeradosPelaIa();

        _geradoComIa = false;
        _dataProcessamentoIa = null;
        _erroProcessamentoIa = '';
        _erroAudio = '';
        _revisadoPeloProfissional = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Áudio removido da sessão.'),
        ),
      );
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        _erroAudio = 'Não foi possível remover o áudio. Detalhes: $erro';
      });
    }
  }

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

      setState(() {
        _transcrevendoRelato = true;
        _reproduzindoAudio = false;
        _statusProcessamento = 'transcrevendo';
        _erroProcessamentoIa = '';
        _erroAudio = '';
        _revisadoPeloProfissional = false;
      });

      final resultado = await _transcricaoRelatoService.transcreverAudio(
        audioRelatoPath: _audioRelatoPath,
        audioRelatoBase64: _audioRelatoBase64,
        sessaoId: _sessaoId,
      );

      if (!mounted) return;

      if (resultado.sucesso) {
        final textoTranscrito = resultado.transcricao.trim();

        if (textoTranscrito.isEmpty) {
          setState(() {
            _statusProcessamento = 'audio_gravado';
            _transcrevendoRelato = false;
            _erroProcessamentoIa =
                'O serviço de transcrição concluiu a operação, mas não retornou texto.';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A transcrição não retornou nenhum texto.'),
            ),
          );

          return;
        }

        setState(() {
          _atualizarTranscricaoProgramaticamente(textoTranscrito);

          _statusProcessamento = 'transcrito';
          _transcrevendoRelato = false;
          _revisadoPeloProfissional = false;
          _geradoComIa = false;
          _dataProcessamentoIa = null;
          _erroProcessamentoIa = '';
          _avisoInvalidacaoTranscricaoExibido = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transcrição concluída e inserida no campo.'),
          ),
        );

        return;
      }

      setState(() {
        _statusProcessamento = 'audio_gravado';
        _transcrevendoRelato = false;
        _erroProcessamentoIa = resultado.erro;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível transcrever o relato.'),
        ),
      );
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        _statusProcessamento = 'audio_gravado';
        _transcrevendoRelato = false;
        _erroProcessamentoIa =
            'Não foi possível transcrever o relato. Detalhes: $erro';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível transcrever o relato.'),
        ),
      );
    }
  }

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

      setState(() {
        _gerandoSinteseIa = true;
        _reproduzindoAudio = false;
        _statusProcessamento = 'ia_processando';
        _erroProcessamentoIa = '';
        _erroAudio = '';
        _revisadoPeloProfissional = false;
      });

      final resultado = await _iaClinicaService.gerarSinteseClinica(
        sessaoId: _sessaoId,
        numeroSessao: _numeroSessao,
        nomePessoaAtendida: _nomePessoaAtendidaExibicao,
        termoPessoaAtendida: _termoSingular,
        abordagemClinica: _abordagemClinica,
        transcricaoRelato: transcricao,
        relatoManual: relato,
        temaPrincipal: _temaController.text.trim(),
        humor: _humor.round(),
      );

      if (!mounted) return;

      if (resultado.sucesso) {
        _preencherController(
          controller: _relatoPosSessaoController,
          texto: resultado.relatoClinicoOrganizado,
        );

        _preencherController(
          controller: _apontamentosCopilotoController,
          texto: resultado.apontamentosCopiloto,
        );

        _preencherController(
          controller: _eventosController,
          texto: resultado.eventosImportantes,
        );

        _preencherController(
          controller: _evolucaoController,
          texto: resultado.evolucaoClinica,
        );

        _preencherController(
          controller: _observacoesController,
          texto: resultado.observacoes,
        );

        _preencherController(
          controller: _pensamentosController,
          texto: resultado.pensamentosAutomaticos,
        );

        _preencherController(
          controller: _emocoesController,
          texto: resultado.emocoes,
        );

        _preencherController(
          controller: _comportamentosController,
          texto: resultado.comportamentos,
        );

        _preencherController(
          controller: _intervencoesController,
          texto: resultado.intervencoes,
        );

        _preencherController(
          controller: _tecnicasController,
          texto: resultado.tecnicas,
        );

        _preencherController(
          controller: _tarefaController,
          texto: resultado.tarefaCasa,
        );

        _preencherController(
          controller: _planoController,
          texto: resultado.planoProximaSessao,
        );

        setState(() {
          _gerandoSinteseIa = false;
          _geradoComIa = true;
          _dataProcessamentoIa = DateTime.now();
          _statusProcessamento = 'ia_processada';
          _revisadoPeloProfissional = false;
          _erroProcessamentoIa = '';
          _avisoInvalidacaoTranscricaoExibido = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Síntese clínica e campos estruturados gerados para revisão.',
            ),
          ),
        );

        return;
      }

      setState(() {
        _gerandoSinteseIa = false;
        _statusProcessamento =
            _possuiTranscricaoRelato ? 'transcrito' : 'manual';
        _erroProcessamentoIa = resultado.erro;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível gerar a síntese clínica.'),
        ),
      );
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        _gerandoSinteseIa = false;
        _statusProcessamento =
            _possuiTranscricaoRelato ? 'transcrito' : 'manual';
        _erroProcessamentoIa =
            'Não foi possível gerar a síntese clínica. Detalhes: $erro';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível gerar a síntese clínica.'),
        ),
      );
    }
  }

  void _marcarComoRevisado() {
    setState(() {
      _revisadoPeloProfissional = true;
      _statusProcessamento = 'revisado';
      _erroProcessamentoIa = '';
      _erroAudio = '';
      _avisoInvalidacaoTranscricaoExibido = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sessão marcada como revisada pelo profissional.'),
      ),
    );
  }

  void _limparErroProcessamento() {
    setState(() {
      _erroProcessamentoIa = '';

      if (_statusProcessamento == 'erro') {
        _statusProcessamento =
            _origemRelato == 'audio' ? 'audio_gravado' : 'manual';
      }
    });
  }

  void _limparErroAudio() {
    setState(() {
      _erroAudio = '';
    });
  }

  Future<void> _salvarSessao() async {
    if (_salvando) return;

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

      setState(() {
        _reproduzindoAudio = false;
      });
    }

    final tema = _temaController.text.trim();

    if (tema.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o tema principal da sessão.'),
        ),
      );
      return;
    }

    setState(() {
      _salvando = true;
    });

    try {
      if (_editando) {
        final sessao = widget.sessaoExistente!;

        sessao.numeroSessao = _numeroSessao;
        sessao.data = _dataSessao;
        sessao.humor = _humor.round();
        sessao.temaPrincipal = tema;
        sessao.relatoPosSessao = _relatoPosSessaoController.text.trim();
        sessao.transcricaoRelato = _transcricaoRelatoController.text.trim();
        sessao.eventosImportantes = _eventosController.text.trim();
        sessao.pensamentosAutomaticos = _pensamentosController.text.trim();
        sessao.emocoes = _emocoesController.text.trim();
        sessao.comportamentos = _comportamentosController.text.trim();
        sessao.intervencoes = _intervencoesController.text.trim();
        sessao.tecnicasTcc = _tecnicasController.text.trim();
        sessao.tarefaCasa = _tarefaController.text.trim();
        sessao.evolucaoClinica = _evolucaoController.text.trim();
        sessao.planoProximaSessao = _planoController.text.trim();
        sessao.observacoes = _observacoesController.text.trim();
        sessao.apontamentosCopiloto =
            _apontamentosCopilotoController.text.trim();

        sessao.audioRelatoPath = _audioRelatoPath;
        sessao.audioRelatoBase64 = _audioRelatoBase64;
        sessao.dataProcessamentoIa = _dataProcessamentoIa;
        sessao.geradoComIa = _geradoComIa;
        sessao.statusProcessamento = _statusProcessamento;
        sessao.audioMantido = _audioMantido;
        sessao.revisadoPeloProfissional = _revisadoPeloProfissional;
        sessao.erroProcessamentoIa = _erroProcessamentoIa;
        sessao.origemRelato = _origemRelato;

        await _sessaoService.atualizarSessao(sessao);
      } else {
        final novaSessao = Sessao(
          id: _sessaoId,
          pacienteId: widget.paciente.id,
          numeroSessao: _numeroSessao,
          data: _dataSessao,
          humor: _humor.round(),
          temaPrincipal: tema,
          relatoPosSessao: _relatoPosSessaoController.text.trim(),
          transcricaoRelato: _transcricaoRelatoController.text.trim(),
          eventosImportantes: _eventosController.text.trim(),
          pensamentosAutomaticos: _pensamentosController.text.trim(),
          emocoes: _emocoesController.text.trim(),
          comportamentos: _comportamentosController.text.trim(),
          intervencoes: _intervencoesController.text.trim(),
          tecnicasTcc: _tecnicasController.text.trim(),
          tarefaCasa: _tarefaController.text.trim(),
          evolucaoClinica: _evolucaoController.text.trim(),
          planoProximaSessao: _planoController.text.trim(),
          observacoes: _observacoesController.text.trim(),
          apontamentosCopiloto: _apontamentosCopilotoController.text.trim(),
          audioRelatoPath: _audioRelatoPath,
          audioRelatoBase64: _audioRelatoBase64,
          dataProcessamentoIa: _dataProcessamentoIa,
          geradoComIa: _geradoComIa,
          statusProcessamento: _statusProcessamento,
          audioMantido: _audioMantido,
          revisadoPeloProfissional: _revisadoPeloProfissional,
          erroProcessamentoIa: _erroProcessamentoIa,
          origemRelato: _origemRelato,
        );

        await _sessaoService.adicionarSessao(novaSessao);
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
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();

    return '$dia/$mes/$ano';
  }

  String _formatarHorario(DateTime data) {
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');

    return '$hora:$minuto';
  }

  String _formatarDataHora(DateTime data) {
    return '${_formatarData(data)} às ${_formatarHorario(data)}';
  }

  String _labelStatusProcessamento() {
    if (_gravandoAudio && _audioPausado) return 'Gravação pausada';
    if (_gravandoAudio) return 'Gravando relato';
    if (_reproduzindoAudio) return 'Reproduzindo áudio';
    if (_transcrevendoRelato) return 'Transcrevendo relato';
    if (_gerandoSinteseIa) return 'Gerando síntese clínica';

    switch (_statusProcessamento) {
      case 'manual':
        return 'Manual';
      case 'audio_gravado':
        return 'Áudio gravado';
      case 'transcrevendo':
        return 'Transcrevendo relato';
      case 'transcrito':
        return 'Transcrição concluída';
      case 'ia_processando':
        return 'Gerando síntese clínica';
      case 'ia_processada':
        return 'Processado por IA';
      case 'revisado':
        return 'Revisado pelo profissional';
      case 'erro':
        return 'Erro no processamento';
      default:
        return 'Status não identificado';
    }
  }

  Color _corStatusProcessamento() {
    if (_gravandoAudio) return Colors.redAccent;
    if (_reproduzindoAudio) return Colors.blue;
    if (_transcrevendoRelato) return Colors.deepPurple;
    if (_gerandoSinteseIa) return Colors.purple;

    switch (_statusProcessamento) {
      case 'revisado':
        return Colors.green;
      case 'ia_processada':
      case 'ia_processando':
      case 'transcrito':
      case 'transcrevendo':
        return Colors.orange;
      case 'erro':
        return Colors.red;
      case 'audio_gravado':
        return Colors.blueGrey;
      case 'manual':
      default:
        return Colors.black54;
    }
  }

  IconData _iconeStatusProcessamento() {
    if (_gravandoAudio && _audioPausado) return Icons.pause_circle_outline;
    if (_gravandoAudio) return Icons.fiber_manual_record;
    if (_reproduzindoAudio) return Icons.volume_up_outlined;
    if (_transcrevendoRelato) return Icons.transcribe_outlined;
    if (_gerandoSinteseIa) return Icons.auto_awesome_outlined;

    switch (_statusProcessamento) {
      case 'revisado':
        return Icons.verified_outlined;
      case 'ia_processando':
      case 'ia_processada':
        return Icons.auto_awesome_outlined;
      case 'transcrevendo':
      case 'transcrito':
        return Icons.notes_outlined;
      case 'erro':
        return Icons.error_outline;
      case 'audio_gravado':
        return Icons.mic_outlined;
      case 'manual':
      default:
        return Icons.edit_note_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color corPrincipal = Color(0xFF1F6F78);
    final configuracao = _configuracaoAbordagem;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA),
      appBar: AppBar(
        title: Text(_editando ? 'Editar sessão' : 'Nova sessão'),
        backgroundColor: corPrincipal,
        foregroundColor: Colors.white,
        actions: _editando
            ? [
                IconButton(
                  tooltip: 'Exportar PDF',
                  icon: const Icon(Icons.file_download_outlined),
                  onPressed: _exportarSessao,
                ),
              ]
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _cardCabecalho(configuracao),
          const SizedBox(height: 16),
          _cardInformacoesGerais(corPrincipal),
          const SizedBox(height: 16),
          _secaoRelatoIa(corPrincipal),
          const SizedBox(height: 16),
          _secaoSinteseClinica(configuracao),
          const SizedBox(height: 16),
          _secaoFormulaClinica(configuracao),
          const SizedBox(height: 16),
          _secaoIntervencoes(configuracao),
          const SizedBox(height: 16),
          _secaoPlano(configuracao),
          const SizedBox(height: 16),
          _secaoApontamentosCopiloto(configuracao),
          const SizedBox(height: 24),
          _botaoSalvar(corPrincipal),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _exportarSessao() async {
    final sessao = widget.sessaoExistente;
    final perfil = _perfilService.obterPerfil();

    if (sessao == null || perfil == null) return;

    try {
      await PdfExportService().exportarSessao(
        sessao: sessao,
        paciente: widget.paciente,
        perfil: perfil,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível exportar o PDF.'),
          ),
        );
      }
    }
  }

  Widget _cardCabecalho(ConfiguracaoAbordagemClinica configuracao) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _nomePessoaAtendidaExibicao,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sessão $_numeroSessao',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Text(
              'Abordagem: ${configuracao.nomeAbordagem}',
              style: const TextStyle(
                color: Colors.black45,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardInformacoesGerais(Color corPrincipal) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informações gerais',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selecionarData,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data da sessão',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(_formatarData(_dataSessao)),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selecionarHorario,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Horário da sessão',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.schedule_outlined),
                ),
                child: Text(_formatarHorario(_dataSessao)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _temaController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Tema principal',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Humor $_doOuDa $_termoSingular: ${_humor.round()}/10',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Slider(
              value: _humor,
              min: 0,
              max: 10,
              divisions: 10,
              label: _humor.round().toString(),
              activeColor: corPrincipal,
              onChanged: (value) {
                setState(() {
                  _humor = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _secaoRelatoIa(Color corPrincipal) {
    return SecaoFormulario(
      titulo: 'Relato pós-sessão com IA',
      subtitulo:
          'Grave o relato do profissional após a sessão, transcreva o áudio, revise a transcrição e só então gere a síntese clínica com IA.',
      children: [
        StatusProcessamentoCard(
          status: _labelStatusProcessamento(),
          cor: _corStatusProcessamento(),
          icone: _iconeStatusProcessamento(),
          origemRelato: _origemRelato,
          geradoComIa: _geradoComIa,
          revisadoPeloProfissional: _revisadoPeloProfissional,
          dataProcessamentoIa: _dataProcessamentoIa == null
              ? null
              : _formatarDataHora(_dataProcessamentoIa!),
          possuiAudioRelato: _possuiAudioRelato,
          audioMantido: _audioMantido,
        ),
        if (_gravandoAudio || _duracaoGravacao > Duration.zero) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _audioPausado
                      ? Icons.pause_circle_outline
                      : Icons.fiber_manual_record,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 10),
                Text(
                  _audioPausado ? 'Pausado' : 'Tempo de gravação',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatarDuracaoGravacao(_duracaoGravacao),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_transcrevendoRelato || _gerandoSinteseIa) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.deepPurple.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _gerandoSinteseIa
                        ? 'Gerando síntese clínica a partir da transcrição. Aguarde...'
                        : 'Transcrevendo o relato. Aguarde...',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_possuiErroProcessamentoIa) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _erroProcessamentoIa,
                    style: const TextStyle(
                      color: Colors.red,
                      height: 1.4,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _limparErroProcessamento,
                  icon: const Icon(Icons.close),
                  color: Colors.red,
                  tooltip: 'Limpar erro',
                ),
              ],
            ),
          ),
        ],
        if (_possuiErroAudio) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.volume_off_outlined,
                  color: Colors.orange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _erroAudio,
                    style: const TextStyle(
                      color: Colors.orange,
                      height: 1.4,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _limparErroAudio,
                  icon: const Icon(Icons.close),
                  color: Colors.orange,
                  tooltip: 'Limpar erro de áudio',
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          'Áudio do relato',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (!_gravandoAudio)
              OutlinedButton.icon(
                onPressed: _existeAcaoEmAndamento
                    ? null
                    : _iniciarGravacaoRelato,
                icon: const Icon(Icons.mic_outlined),
                label: Text(
                  _possuiAudioRelato
                      ? 'Gravar novamente'
                      : 'Iniciar gravação',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: corPrincipal,
                  side: BorderSide(color: corPrincipal),
                ),
              ),
            if (_gravandoAudio && !_audioPausado)
              OutlinedButton.icon(
                onPressed: _pausarGravacaoRelato,
                icon: const Icon(Icons.pause_outlined),
                label: const Text('Pausar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                ),
              ),
            if (_gravandoAudio && _audioPausado)
              OutlinedButton.icon(
                onPressed: _retomarGravacaoRelato,
                icon: const Icon(Icons.play_arrow_outlined),
                label: const Text('Retomar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: corPrincipal,
                  side: BorderSide(color: corPrincipal),
                ),
              ),
            if (_gravandoAudio)
              OutlinedButton.icon(
                onPressed: _pararGravacaoRelato,
                icon: const Icon(Icons.stop_outlined),
                label: const Text('Finalizar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            if (_gravandoAudio)
              OutlinedButton.icon(
                onPressed: _cancelarGravacaoRelato,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Cancelar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black54,
                ),
              ),
            if (_possuiAudioRelato && !_gravandoAudio)
              OutlinedButton.icon(
                onPressed: _existeAcaoEmAndamento
                    ? null
                    : _ouvirOuPararAudioRelato,
                icon: Icon(
                  _reproduzindoAudio
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline,
                ),
                label: Text(
                  _reproduzindoAudio ? 'Parar áudio' : 'Ouvir áudio',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      _reproduzindoAudio ? Colors.red : corPrincipal,
                  side: BorderSide(
                    color:
                        _reproduzindoAudio ? Colors.red : corPrincipal,
                  ),
                ),
              ),
            if (_possuiAudioRelato && !_gravandoAudio)
              OutlinedButton.icon(
                onPressed: _existeAcaoEmAndamento
                    ? null
                    : _removerAudioRelato,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remover áudio'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            OutlinedButton.icon(
              onPressed:
                  _existeAcaoEmAndamento ? null : _transcreverRelato,
              icon: _transcrevendoRelato
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.transcribe_outlined),
              label: Text(
                _transcrevendoRelato
                    ? 'Transcrevendo...'
                    : 'Transcrever áudio',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: corPrincipal,
                side: BorderSide(color: corPrincipal),
              ),
            ),
          ],
        ),
        if (_possuiAudioRelato) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _audioRelatoPath.trim().isNotEmpty
                      ? 'Áudio vinculado: $_audioRelatoPath'
                      : 'Áudio vinculado: armazenamento interno Base64',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ),
              Switch(
                value: _audioMantido,
                activeThumbColor: corPrincipal,
                onChanged: _existeAcaoEmAndamento
                    ? null
                    : (value) {
                        setState(() {
                          _audioMantido = value;
                        });
                      },
              ),
            ],
          ),
          Text(
            _possuiAudioRelatoBase64
                ? 'Manter áudio original • Backup Base64 disponível'
                : 'Manter áudio original',
            style: const TextStyle(
              color: Colors.black45,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 18),
        const Divider(),
        const SizedBox(height: 12),
        const Text(
          'Transcrição e revisão antes da IA',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'A IA usará principalmente a transcrição abaixo. Revise, edite ou complemente este texto antes de gerar a síntese clínica.',
          style: TextStyle(
            color: Colors.black54,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        CampoTextoWidget(
          controller: _transcricaoRelatoController,
          label: 'Transcrição bruta do relato',
          maxLines: 5,
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed:
                _existeAcaoEmAndamento ? null : _gerarSinteseComIa,
            icon: _gerandoSinteseIa
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(
              _gerandoSinteseIa
                  ? 'Gerando...'
                  : 'Gerar síntese com IA',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: corPrincipal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Divider(),
        const SizedBox(height: 12),
        const Text(
          'Resultado clínico para revisão',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        CampoTextoWidget(
          controller: _relatoPosSessaoController,
          label: 'Relato clínico organizado para revisão',
          maxLines: 8,
        ),
        if (_estaAguardandoRevisao ||
            (!_revisadoPeloProfissional &&
                (_geradoComIa || _possuiTranscricaoRelato))) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  _existeAcaoEmAndamento ? null : _marcarComoRevisado,
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Marcar como revisado pelo profissional'),
              style: FilledButton.styleFrom(
                backgroundColor: corPrincipal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _secaoSinteseClinica(ConfiguracaoAbordagemClinica configuracao) {
    return SecaoFormulario(
      titulo: 'Síntese clínica',
      subtitulo:
          'Campos estruturados que futuramente poderão ser sugeridos pela IA e revisados pelo profissional.',
      children: [
        CampoTextoWidget(
          controller: _eventosController,
          label: configuracao.eventosLabel,
          maxLines: 4,
        ),
        CampoTextoWidget(
          controller: _evolucaoController,
          label: configuracao.evolucaoLabel,
          maxLines: 4,
        ),
        CampoTextoWidget(
          controller: _observacoesController,
          label: 'Observações livres',
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _secaoFormulaClinica(ConfiguracaoAbordagemClinica configuracao) {
    return SecaoFormulario(
      titulo: configuracao.tituloFormulaClinica,
      subtitulo: configuracao.subtituloFormulaClinica,
      children: [
        CampoTextoWidget(
          controller: _pensamentosController,
          label: configuracao.campo1Label,
          maxLines: 3,
        ),
        CampoTextoWidget(
          controller: _emocoesController,
          label: configuracao.campo2Label,
          maxLines: 3,
        ),
        CampoTextoWidget(
          controller: _comportamentosController,
          label: configuracao.campo3Label,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _secaoIntervencoes(ConfiguracaoAbordagemClinica configuracao) {
    return SecaoFormulario(
      titulo: configuracao.tituloIntervencoes,
      children: [
        CampoTextoWidget(
          controller: _intervencoesController,
          label: configuracao.intervencoesLabel,
          maxLines: 4,
        ),
        CampoTextoWidget(
          controller: _tecnicasController,
          label: configuracao.tecnicasLabel,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _secaoPlano(ConfiguracaoAbordagemClinica configuracao) {
    return SecaoFormulario(
      titulo: configuracao.tituloPlano,
      children: [
        CampoTextoWidget(
          controller: _tarefaController,
          label: configuracao.tarefaLabel,
          maxLines: 3,
        ),
        CampoTextoWidget(
          controller: _planoController,
          label: configuracao.planoLabel,
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _secaoApontamentosCopiloto(ConfiguracaoAbordagemClinica configuracao) {
    return SecaoFormulario(
      titulo: 'Apontamentos do Copiloto',
      subtitulo:
          'Espaço para hipóteses, focos de atenção e possibilidades clínicas sugeridas pela IA, sempre para revisão do profissional e considerando a abordagem ${configuracao.nomeAbordagem}.',
      children: [
        CampoTextoWidget(
          controller: _apontamentosCopilotoController,
          label: configuracao.apontamentosCopilotoLabel,
          maxLines: 6,
        ),
      ],
    );
  }

  Widget _botaoSalvar(Color corPrincipal) {
    return FilledButton.icon(
      onPressed: _salvando ? null : _salvarSessao,
      icon: _salvando
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.save_outlined),
      label: Text(_salvando ? 'Salvando...' : 'Salvar sessão'),
      style: FilledButton.styleFrom(
        backgroundColor: corPrincipal,
        foregroundColor: Colors.white,
        disabledBackgroundColor: corPrincipal.withValues(alpha: 0.6),
        disabledForegroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}

