import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/configuracao_abordagem_clinica.dart';
import '../models/paciente.dart';
import '../models/sessao.dart';
import '../providers/service_providers.dart';
import '../services/audio_relato_service.dart';
import '../services/ia_clinica_service.dart';
import '../services/logger.dart';
import '../services/pdf_export_service.dart';
import '../services/sessao_service.dart';
import '../services/transcricao_relato_service.dart';
import '../widgets/campo_texto_widget.dart';
import '../widgets/secao_campos_clinicos_widget.dart';
import '../widgets/secao_formulario.dart';

final _salvandoProvider = StateProvider<bool>((ref) => false);
final _dataSessaoProvider = StateProvider<DateTime>((ref) => DateTime.now());
final _humorProvider = StateProvider<double>((ref) => 5);
final _gravandoAudioProvider = StateProvider<bool>((ref) => false);
final _audioPausadoProvider = StateProvider<bool>((ref) => false);
final _reproduzindoAudioProvider = StateProvider<bool>((ref) => false);
final _duracaoGravacaoProvider = StateProvider<Duration>((ref) => Duration.zero);
final _audioRelatoPathProvider = StateProvider<String>((ref) => '');
final _audioRelatoBase64Provider = StateProvider<String>((ref) => '');
final _erroAudioProvider = StateProvider<String>((ref) => '');
final _formRebuildProvider = StateProvider<int>((ref) => 0);
final _transcrevendoRelatoProvider = StateProvider<bool>((ref) => false);
final _gerandoSinteseIaProvider = StateProvider<bool>((ref) => false);
final _statusProcessamentoProvider = StateProvider<String>((ref) => 'manual');
final _erroProcessamentoIaProvider = StateProvider<String>((ref) => '');
final _revisadoPeloProfissionalProvider = StateProvider<bool>((ref) => false);
final _geradoComIaProvider = StateProvider<bool>((ref) => false);
final _dataProcessamentoIaProvider = StateProvider<DateTime?>((ref) => null);
final _avisoInvalidacaoTranscricaoExibidoProvider = StateProvider<bool>((ref) => false);
final _audioMantidoProvider = StateProvider<bool>((ref) => false);
final _origemRelatoProvider = StateProvider<String>((ref) => 'manual');
final _artigosSugeridosProvider = StateProvider<String>((ref) => '');
final _modoEdicaoProvider = StateProvider<bool>((ref) => false);

class SessaoFormPage extends ConsumerStatefulWidget {
  final Paciente paciente;
  final Sessao? sessaoExistente;

  const SessaoFormPage({
    super.key,
    required this.paciente,
    this.sessaoExistente,
  });

  @override
  ConsumerState<SessaoFormPage> createState() => _SessaoFormPageState();
}

class _SessaoFormPageState extends ConsumerState<SessaoFormPage> {
  late final SessaoService _sessaoService;
  late final AudioRelatoService _audioRelatoService;
  late final TranscricaoRelatoService _transcricaoRelatoService;
  late final IaClinicaService _iaClinicaService;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _erroInicializacao;

  StreamSubscription<void>? _audioPlayerCompleteSubscription;

  final TextEditingController _relatoPosSessaoController =
      TextEditingController();
  final TextEditingController _transcricaoRelatoController =
      TextEditingController();
  final TextEditingController _sinteseController = TextEditingController();
  final TextEditingController _formulacaoController = TextEditingController();
  final TextEditingController _intervencoesController =
      TextEditingController();
  final TextEditingController _apontamentosController =
      TextEditingController();

  late String _sessaoId;
  late int _numeroSessao;

  Timer? _timerGravacao;

  static const Duration _duracaoMaximaAudio = Duration(minutes: 5);

  bool get _transcrevendoRelato => ref.read(_transcrevendoRelatoProvider);
  set _transcrevendoRelato(bool v) => ref.read(_transcrevendoRelatoProvider.notifier).state = v;

  bool get _gerandoSinteseIa => ref.read(_gerandoSinteseIaProvider);
  set _gerandoSinteseIa(bool v) => ref.read(_gerandoSinteseIaProvider.notifier).state = v;

  String get _statusProcessamento => ref.read(_statusProcessamentoProvider);
  set _statusProcessamento(String v) => ref.read(_statusProcessamentoProvider.notifier).state = v;

  String get _erroProcessamentoIa => ref.read(_erroProcessamentoIaProvider);
  set _erroProcessamentoIa(String v) => ref.read(_erroProcessamentoIaProvider.notifier).state = v;

  bool get _revisadoPeloProfissional => ref.read(_revisadoPeloProfissionalProvider);
  set _revisadoPeloProfissional(bool v) => ref.read(_revisadoPeloProfissionalProvider.notifier).state = v;

  bool get _geradoComIa => ref.read(_geradoComIaProvider);
  set _geradoComIa(bool v) => ref.read(_geradoComIaProvider.notifier).state = v;

  DateTime? get _dataProcessamentoIa => ref.read(_dataProcessamentoIaProvider);
  set _dataProcessamentoIa(DateTime? v) => ref.read(_dataProcessamentoIaProvider.notifier).state = v;

  bool get _avisoInvalidacaoTranscricaoExibido => ref.read(_avisoInvalidacaoTranscricaoExibidoProvider);
  set _avisoInvalidacaoTranscricaoExibido(bool v) => ref.read(_avisoInvalidacaoTranscricaoExibidoProvider.notifier).state = v;

  bool get _audioMantido => ref.read(_audioMantidoProvider);
  set _audioMantido(bool v) => ref.read(_audioMantidoProvider.notifier).state = v;

  String get _origemRelato => ref.read(_origemRelatoProvider);
  set _origemRelato(String v) => ref.read(_origemRelatoProvider.notifier).state = v;

  String get _artigosSugeridos => ref.read(_artigosSugeridosProvider);
  set _artigosSugeridos(String v) => ref.read(_artigosSugeridosProvider.notifier).state = v;

  bool get _modoEdicao => ref.read(_modoEdicaoProvider);
  set _modoEdicao(bool v) => ref.read(_modoEdicaoProvider.notifier).state = v;

  void _triggerRebuild() {
    if (mounted) ref.read(_formRebuildProvider.notifier).state++;
  }

  void _registrarAuditoria(String tipo, String descricao) {
    try {
      ref.read(auditoriaServiceProvider).registrar(
            tipoEvento: tipo,
            descricao: descricao,
            pacienteId: widget.paciente.id,
          );
    } catch (_) {}
  }

  bool get _gravandoAudio => ref.read(_gravandoAudioProvider);
  set _gravandoAudio(bool valor) =>
      ref.read(_gravandoAudioProvider.notifier).state = valor;

  bool get _audioPausado => ref.read(_audioPausadoProvider);
  set _audioPausado(bool valor) =>
      ref.read(_audioPausadoProvider.notifier).state = valor;

  bool get _reproduzindoAudio => ref.read(_reproduzindoAudioProvider);
  set _reproduzindoAudio(bool valor) =>
      ref.read(_reproduzindoAudioProvider.notifier).state = valor;

  Duration get _duracaoGravacao => ref.read(_duracaoGravacaoProvider);
  set _duracaoGravacao(Duration valor) =>
      ref.read(_duracaoGravacaoProvider.notifier).state = valor;

  String get _audioRelatoPath => ref.read(_audioRelatoPathProvider);
  set _audioRelatoPath(String valor) =>
      ref.read(_audioRelatoPathProvider.notifier).state = valor;

  String get _audioRelatoBase64 => ref.read(_audioRelatoBase64Provider);
  set _audioRelatoBase64(String valor) =>
      ref.read(_audioRelatoBase64Provider.notifier).state = valor;

  String get _erroAudio => ref.read(_erroAudioProvider);

  String _ultimaTranscricaoControlada = '';
  bool _alteracaoProgramaticaTranscricao = false;

  bool get _editando => widget.sessaoExistente != null;

  bool get _existeAcaoEmAndamento {
    return ref.read(_gravandoAudioProvider) || _transcrevendoRelato || _gerandoSinteseIa;
  }

  String get _termoSingular {
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    return perfil?.termoSingular ?? 'paciente';
  }

  String get _termoSingularCapitalizado {
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    return perfil?.termoSingularCapitalizado ?? 'Paciente';
  }

  bool get _termoFeminino {
    return _termoSingular == 'pessoa atendida';
  }

  String get _doOuDa {
    return _termoFeminino ? 'da' : 'do';
  }

  String get _abordagemClinica {
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
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
    return ref.read(_audioRelatoPathProvider).trim().isNotEmpty ||
        ref.read(_audioRelatoBase64Provider).trim().isNotEmpty;
  }

  bool get _possuiAudioRelatoBase64 {
    return ref.read(_audioRelatoBase64Provider).trim().isNotEmpty;
  }

  bool get _possuiTranscricaoRelato {
    return _transcricaoRelatoController.text.trim().isNotEmpty;
  }

  bool get _possuiErroProcessamentoIa {
    return _erroProcessamentoIa.trim().isNotEmpty;
  }

  bool get _possuiErroAudio {
    return ref.read(_erroAudioProvider).trim().isNotEmpty;
  }

  bool get _estaAguardandoRevisao {
    return _statusProcessamento == 'audio_gravado' ||
        _statusProcessamento == 'transcrevendo' ||
        _statusProcessamento == 'transcrito' ||
        _statusProcessamento == 'ia_processando' ||
        _statusProcessamento == 'ia_processada';
  }

  String _concatenarSintese(Sessao s) {
    final partes = <String>[];
    if (s.eventosImportantes.trim().isNotEmpty) partes.add(s.eventosImportantes.trim());
    if (s.evolucaoClinica.trim().isNotEmpty) partes.add(s.evolucaoClinica.trim());
    if (s.observacoes.trim().isNotEmpty) partes.add(s.observacoes.trim());
    return partes.join('\n\n');
  }

  String _concatenarFormulacao(Sessao s) {
    final partes = <String>[];
    if (s.pensamentosAutomaticos.trim().isNotEmpty) partes.add(s.pensamentosAutomaticos.trim());
    if (s.emocoes.trim().isNotEmpty) partes.add(s.emocoes.trim());
    if (s.comportamentos.trim().isNotEmpty) partes.add(s.comportamentos.trim());
    return partes.join('\n\n');
  }

  @override
  void initState() {
    super.initState();

    try {
      _sessaoService = ref.read(sessaoServiceProvider);
      _audioRelatoService = ref.read(audioRelatoServiceProvider);
      _transcricaoRelatoService = ref.read(transcricaoRelatoServiceProvider);
      _iaClinicaService = ref.read(iaClinicaServiceProvider);

      _audioPlayerCompleteSubscription = _audioPlayer.onPlayerComplete.listen(
        (_) {
          if (!mounted) return;

          _reproduzindoAudio = false;
          _triggerRebuild();
        },
      );

      final sessao = widget.sessaoExistente;

      if (sessao != null) {
        _audioRelatoService.cancelarGravacao();

        _sessaoId = sessao.id;
        _numeroSessao = sessao.numeroSessao;
        ref.read(_dataSessaoProvider.notifier).state = sessao.data;

        _relatoPosSessaoController.text = sessao.relatoPosSessao;
        _transcricaoRelatoController.text = sessao.transcricaoRelato;
        _sinteseController.text = _concatenarSintese(sessao);
        _formulacaoController.text = _concatenarFormulacao(sessao);
        _intervencoesController.text = sessao.intervencoes;
        _apontamentosController.text = sessao.apontamentosCopiloto;

        ref.read(_audioRelatoPathProvider.notifier).state = sessao.audioRelatoPath;
        ref.read(_audioRelatoBase64Provider.notifier).state = sessao.audioRelatoBase64;
        _dataProcessamentoIa = sessao.dataProcessamentoIa;
        _geradoComIa = sessao.geradoComIa;
        _statusProcessamento = sessao.statusProcessamento;
        _audioMantido = sessao.audioMantido;
        _revisadoPeloProfissional = sessao.revisadoPeloProfissional;
        _erroProcessamentoIa = sessao.erroProcessamentoIa;
        _artigosSugeridos = sessao.artigosSugeridos;
        _origemRelato = sessao.origemRelato;
        _modoEdicao = false;
      } else {
        _resetarEstadoSessao();
        _sessaoId = DateTime.now().millisecondsSinceEpoch.toString();
        _numeroSessao = _sessaoService.proximoNumeroSessao(widget.paciente.id);
        ref.read(_dataSessaoProvider.notifier).state = DateTime.now();
        _modoEdicao = true;
      }

      _ultimaTranscricaoControlada = _transcricaoRelatoController.text;
      _transcricaoRelatoController.addListener(_aoAlterarTranscricaoRelato);
    } catch (e, stack) {
      _erroInicializacao = '$e\n$stack';
      Log.erro(e, contexto: 'sessao_form_page:initState');
    }
  }

  @override
  void dispose() {
    _transcricaoRelatoController.removeListener(_aoAlterarTranscricaoRelato);

    _relatoPosSessaoController.dispose();
    _transcricaoRelatoController.dispose();
    _sinteseController.dispose();
    _formulacaoController.dispose();
    _intervencoesController.dispose();
    _apontamentosController.dispose();

    _timerGravacao?.cancel();
    _audioPlayerCompleteSubscription?.cancel();
    _audioPlayer.dispose();

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

    _invalidarIaERevisaoPorAlteracaoDaTranscricao();
    _triggerRebuild();

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
    _artigosSugeridos = '';

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
    _sinteseController.clear();
    _formulacaoController.clear();
    _intervencoesController.clear();
    _apontamentosController.clear();
    _artigosSugeridos = '';
  }

  void _resetarEstadoSessao() {
    ref.read(_audioRelatoPathProvider.notifier).state = '';
    ref.read(_audioRelatoBase64Provider.notifier).state = '';
    ref.read(_gravandoAudioProvider.notifier).state = false;
    ref.read(_audioPausadoProvider.notifier).state = false;
    ref.read(_reproduzindoAudioProvider.notifier).state = false;
    ref.read(_duracaoGravacaoProvider.notifier).state = Duration.zero;
    ref.read(_erroAudioProvider.notifier).state = '';
    ref.read(_transcrevendoRelatoProvider.notifier).state = false;
    ref.read(_gerandoSinteseIaProvider.notifier).state = false;
    ref.read(_statusProcessamentoProvider.notifier).state = 'manual';
    ref.read(_erroProcessamentoIaProvider.notifier).state = '';
    ref.read(_revisadoPeloProfissionalProvider.notifier).state = false;
    ref.read(_geradoComIaProvider.notifier).state = false;
    ref.read(_dataProcessamentoIaProvider.notifier).state = null;
    ref.read(_avisoInvalidacaoTranscricaoExibidoProvider.notifier).state = false;
    ref.read(_audioMantidoProvider.notifier).state = false;
    ref.read(_origemRelatoProvider.notifier).state = 'manual';
    ref.read(_artigosSugeridosProvider.notifier).state = '';
    ref.read(_salvandoProvider.notifier).state = false;
    ref.read(_formRebuildProvider.notifier).state = 0;

    _relatoPosSessaoController.clear();
    _transcricaoRelatoController.clear();
    _sinteseController.clear();
    _formulacaoController.clear();
    _intervencoesController.clear();
    _apontamentosController.clear();

    _ultimaTranscricaoControlada = '';
    _avisoInvalidacaoTranscricaoExibido = false;
    _timerGravacao?.cancel();
    _timerGravacao = null;

    _audioRelatoService.cancelarGravacao();
  }

  void _iniciarContadorGravacao() {
    _timerGravacao?.cancel();

    ref.read(_duracaoGravacaoProvider.notifier).state = Duration.zero;

    _timerGravacao = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;

        final novaDuracao =
            ref.read(_duracaoGravacaoProvider) + const Duration(seconds: 1);
        ref.read(_duracaoGravacaoProvider.notifier).state = novaDuracao;
        _triggerRebuild();

        if (novaDuracao >= _duracaoMaximaAudio) {
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
            ref.read(_duracaoGravacaoProvider) + const Duration(seconds: 1);
        ref.read(_duracaoGravacaoProvider.notifier).state = novaDuracao;
        _triggerRebuild();

        if (novaDuracao >= _duracaoMaximaAudio) {
          _pararGravacaoRelato();
        }
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
    final base64Audio = _normalizarAudioBase64(ref.read(_audioRelatoBase64Provider));

    if (base64Audio.isEmpty) {
      return null;
    }

    return BytesSource(base64Decode(base64Audio));
  }

  Future<void> _selecionarData() async {
    final dataAtual = ref.read(_dataSessaoProvider);
    final dataEscolhida = await showDatePicker(
      context: context,
      initialDate: dataAtual,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (!mounted || dataEscolhida == null) return;

    ref.read(_dataSessaoProvider.notifier).state = DateTime(
      dataEscolhida.year,
      dataEscolhida.month,
      dataEscolhida.day,
      dataAtual.hour,
      dataAtual.minute,
    );
  }

  Future<void> _selecionarHorario() async {
    final dataAtual = ref.read(_dataSessaoProvider);
    final horarioAtual = TimeOfDay(
      hour: dataAtual.hour,
      minute: dataAtual.minute,
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

    ref.read(_dataSessaoProvider.notifier).state = DateTime(
      dataAtual.year,
      dataAtual.month,
      dataAtual.day,
      horarioEscolhido.hour,
      horarioEscolhido.minute,
    );
  }

  Future<void> _iniciarGravacaoRelato() async {
    if (_existeAcaoEmAndamento) return;

    try {
      if (ref.read(_reproduzindoAudioProvider)) {
        await _audioPlayer.stop();
      }

      await _audioRelatoService.iniciarGravacao(
        sessaoId: _sessaoId,
      );

      _iniciarContadorGravacao();

      if (!mounted) return;

      _origemRelato = 'audio';
      ref.read(_erroAudioProvider.notifier).state = '';
      ref.read(_gravandoAudioProvider.notifier).state = true;
      ref.read(_audioPausadoProvider.notifier).state = false;
      ref.read(_reproduzindoAudioProvider.notifier).state = false;
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

      ref.read(_erroAudioProvider.notifier).state =
          'Não foi possível iniciar a gravação. Detalhes: $erro';
      ref.read(_gravandoAudioProvider.notifier).state = false;
      ref.read(_audioPausadoProvider.notifier).state = false;
      ref.read(_reproduzindoAudioProvider.notifier).state = false;
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
    if (!ref.read(_gravandoAudioProvider) || ref.read(_audioPausadoProvider)) return;

    try {
      await _audioRelatoService.pausarGravacao();
      _pausarContadorGravacao();

      if (!mounted) return;

      ref.read(_audioPausadoProvider.notifier).state = true;
      ref.read(_erroAudioProvider.notifier).state = '';
      _triggerRebuild();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gravação pausada.'),
        ),
      );
    } catch (erro) {
      if (!mounted) return;

      ref.read(_erroAudioProvider.notifier).state =
          'Não foi possível pausar a gravação. Detalhes: $erro';
      _triggerRebuild();
    }
  }

  Future<void> _retomarGravacaoRelato() async {
    if (!ref.read(_gravandoAudioProvider) || !ref.read(_audioPausadoProvider)) return;

    try {
      await _audioRelatoService.retomarGravacao();
      _retomarContadorGravacao();

      if (!mounted) return;

      ref.read(_audioPausadoProvider.notifier).state = false;
      ref.read(_erroAudioProvider.notifier).state = '';
      _triggerRebuild();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gravação retomada.'),
        ),
      );
    } catch (erro) {
      if (!mounted) return;

      ref.read(_erroAudioProvider.notifier).state =
          'Não foi possível retomar a gravação. Detalhes: $erro';
      _triggerRebuild();
    }
  }

  Future<void> _pararGravacaoRelato() async {
  if (!ref.read(_gravandoAudioProvider)) return;

  try {
    final caminho = await _audioRelatoService.pararGravacao();

    String audioBase64 = '';

    try {
      audioBase64 = await _audioRelatoService.obterAudioAtualBase64();
    } catch (erroBase64) {
      audioBase64 = '';

      if (mounted) {
        ref.read(_erroAudioProvider.notifier).state =
            'O áudio foi gravado, mas não foi possível criar o backup interno em Base64. Detalhes: $erroBase64';
      }
    }

    _pararContadorGravacao();

    if (!mounted) return;

    if (caminho != null && caminho.trim().isNotEmpty) {
      ref.read(_audioRelatoPathProvider.notifier).state = caminho.trim();
    }

    ref.read(_audioRelatoBase64Provider.notifier).state = audioBase64.trim();

    _origemRelato = 'audio';
    _statusProcessamento = 'audio_gravado';
    _audioMantido = true;

    _revisadoPeloProfissional = false;
    _geradoComIa = false;
    _dataProcessamentoIa = null;
    _erroProcessamentoIa = '';

    if (ref.read(_audioRelatoBase64Provider).trim().isNotEmpty) {
      ref.read(_erroAudioProvider.notifier).state = '';
    }

    _atualizarTranscricaoProgramaticamente('');
    _limparCamposGeradosPelaIa();

    ref.read(_gravandoAudioProvider.notifier).state = false;
    ref.read(_audioPausadoProvider.notifier).state = false;
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

    ref.read(_erroAudioProvider.notifier).state =
        'Não foi possível finalizar a gravação. Detalhes: $erro';
    ref.read(_gravandoAudioProvider.notifier).state = false;
    ref.read(_audioPausadoProvider.notifier).state = false;
    _triggerRebuild();
  }
}   

  Future<void> _cancelarGravacaoRelato() async {
    try {
      await _audioRelatoService.cancelarGravacao();
      _pararContadorGravacao();

      if (!mounted) return;

      ref.read(_gravandoAudioProvider.notifier).state = false;
      ref.read(_audioPausadoProvider.notifier).state = false;
      ref.read(_duracaoGravacaoProvider.notifier).state = Duration.zero;
      ref.read(_erroAudioProvider.notifier).state = '';

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

      ref.read(_erroAudioProvider.notifier).state =
          'Não foi possível cancelar a gravação. Detalhes: $erro';
      _triggerRebuild();
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
      if (ref.read(_reproduzindoAudioProvider)) {
        await _audioPlayer.stop();

        if (!mounted) return;

        ref.read(_reproduzindoAudioProvider.notifier).state = false;
        _triggerRebuild();

        return;
      }

      await _audioPlayer.stop();

      final caminhoAudio = ref.read(_audioRelatoPathProvider).trim();

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

      ref.read(_reproduzindoAudioProvider.notifier).state = true;
      ref.read(_erroAudioProvider.notifier).state = '';
      _triggerRebuild();
    } catch (erro) {
      if (!mounted) return;

      ref.read(_reproduzindoAudioProvider.notifier).state = false;
      ref.read(_erroAudioProvider.notifier).state =
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
      if (ref.read(_reproduzindoAudioProvider)) {
        await _audioPlayer.stop();
      }

      await _audioRelatoService.removerAudioAtual();

      if (!mounted) return;

      ref.read(_audioRelatoPathProvider.notifier).state = '';
      ref.read(_audioRelatoBase64Provider.notifier).state = '';
      _audioMantido = false;
      _origemRelato = 'manual';
      _statusProcessamento = 'manual';

      ref.read(_reproduzindoAudioProvider.notifier).state = false;
      ref.read(_gravandoAudioProvider.notifier).state = false;
      ref.read(_audioPausadoProvider.notifier).state = false;
      _transcrevendoRelato = false;
      _gerandoSinteseIa = false;
      ref.read(_duracaoGravacaoProvider.notifier).state = Duration.zero;

      _atualizarTranscricaoProgramaticamente('');
      _limparCamposGeradosPelaIa();

      _geradoComIa = false;
      _dataProcessamentoIa = null;
      _erroProcessamentoIa = '';
      ref.read(_erroAudioProvider.notifier).state = '';
      _revisadoPeloProfissional = false;
      _triggerRebuild();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Áudio removido da sessão.'),
        ),
      );
    } catch (erro) {
      if (!mounted) return;

      ref.read(_erroAudioProvider.notifier).state =
          'Não foi possível remover o áudio. Detalhes: $erro';
      _triggerRebuild();
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

      _transcrevendoRelato = true;
      _reproduzindoAudio = false;
      _statusProcessamento = 'transcrevendo';
      _erroProcessamentoIa = '';
      _revisadoPeloProfissional = false;
      _triggerRebuild();
      ref.read(_erroAudioProvider.notifier).state = '';

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

        _registrarAuditoria('Transcricao concluida', 'Transcricao do audio realizada - sessao $_numeroSessao');

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

      _gerandoSinteseIa = true;
      _reproduzindoAudio = false;
      _statusProcessamento = 'ia_processando';
      _erroProcessamentoIa = '';
      _revisadoPeloProfissional = false;
      _triggerRebuild();
      ref.read(_erroAudioProvider.notifier).state = '';

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

        _artigosSugeridos = resultado.artigosSugeridos;

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

  void _marcarComoRevisado() {
    _revisadoPeloProfissional = true;
    _statusProcessamento = 'revisado';
    _triggerRebuild();
    ref.read(_erroAudioProvider.notifier).state = '';

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
    ref.read(_erroAudioProvider.notifier).state = '';
  }

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

    final tema = _transcricaoRelatoController.text.trim();

    ref.read(_salvandoProvider.notifier).state = true;

    try {
      final dataSessao = ref.read(_dataSessaoProvider);

      if (_editando) {
        final sessao = widget.sessaoExistente!;

        sessao.numeroSessao = _numeroSessao;
        sessao.data = dataSessao;
        sessao.humor = 5;
        sessao.temaPrincipal = tema;
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
          humor: 5,
          temaPrincipal: tema,
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
    if (_erroInicializacao != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F9FA),
        appBar: AppBar(
          title: const Text('Erro'),
          backgroundColor: const Color(0xFFD32F2F),
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 48),
            const SizedBox(height: 16),
            const Text(
              'Nao foi possivel abrir o prontuario',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD32F2F),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Isso pode ser causado por dados incompatíveis de uma versão anterior do app. Tente limpar os dados do aplicativo nas configurações do Android.',
              style: TextStyle(color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _erroInicializacao!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Voltar'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
              ),
            ),
          ],
        ),
      );
    }

    ref.watch(_formRebuildProvider);
    const Color corPrincipal = Color(0xFF2563EB);
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
          IgnorePointer(
            ignoring: _editando && !_modoEdicao,
            child: Column(
              children: [
                _cardInformacoesGerais(corPrincipal),
                const SizedBox(height: 16),
                _secaoRelatoIa(corPrincipal),
                const SizedBox(height: 16),
                SecaoCamposClinicosWidget(
                  configuracao: configuracao,
                  sinteseController: _sinteseController,
                  formulacaoController: _formulacaoController,
                  intervencoesController: _intervencoesController,
                  apontamentosController: _apontamentosController,
                ),
                if (_artigosSugeridos.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _secaoArtigosSugeridos(),
                ],
              ],
            ),
          ),
          if (_modoEdicao || !_editando) ...[
            const SizedBox(height: 16),
            _botaoSalvar(corPrincipal),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _exportarSessao() async {
    final sessao = widget.sessaoExistente;
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();

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
              _nomePessoaAtendidaExibicao.toUpperCase(),
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sessão $_numeroSessao',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
                if (_editando && !_modoEdicao)
                  TextButton.icon(
                    onPressed: () {
                      _modoEdicao = true;
                      _triggerRebuild();
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar'),
                  ),
              ],
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
            InkWell(
              onTap: _selecionarData,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data da sessão',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(_formatarData(ref.watch(_dataSessaoProvider))),
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
                child: Text(_formatarHorario(ref.watch(_dataSessaoProvider))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secaoRelatoIa(Color corPrincipal) {
    return SecaoFormulario(
      children: [
        _timerGravacaoWidget(),
        _processamentoEmAndamentoWidget(),
        _erroProcessamentoIaWidget(),
        _erroAudioWidget(),
        _botoesAudioWidget(corPrincipal),
        _audioInfoWidget(corPrincipal),
        const SizedBox(height: 12),
        CampoTextoWidget(
          controller: _transcricaoRelatoController,
          label: 'Transcrição',
          maxLines: 5,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _existeAcaoEmAndamento ? null : _gerarSinteseComIa,
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
              _gerandoSinteseIa ? 'Gerando...' : 'Gerar síntese com IA',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: corPrincipal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        CampoTextoWidget(
          controller: _relatoPosSessaoController,
          label: 'Relato clínico organizado',
          maxLines: 8,
        ),
        if (_estaAguardandoRevisao ||
            (!_revisadoPeloProfissional &&
                (_geradoComIa || _possuiTranscricaoRelato))) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _existeAcaoEmAndamento ? null : _marcarComoRevisado,
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Marcar como revisado'),
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

  Widget _timerGravacaoWidget() {
    if (!_gravandoAudio && _duracaoGravacao <= Duration.zero) {
      return const SizedBox.shrink();
    }
    return Column(children: [
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
    ]);
  }

  Widget _processamentoEmAndamentoWidget() {
    if (!_transcrevendoRelato && !_gerandoSinteseIa) {
      return const SizedBox.shrink();
    }
    return Column(children: [
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
    ]);
  }

  Widget _erroProcessamentoIaWidget() {
    if (!_possuiErroProcessamentoIa) return const SizedBox.shrink();
    return Column(children: [
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
                style: const TextStyle(color: Colors.red, height: 1.4),
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
    ]);
  }

  Widget _erroAudioWidget() {
    if (!_possuiErroAudio) return const SizedBox.shrink();
    return Column(children: [
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
            const Icon(Icons.volume_off_outlined, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ref.watch(_erroAudioProvider),
                style: const TextStyle(color: Colors.orange, height: 1.4),
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
    ]);
  }

  Widget _botoesAudioWidget(Color corPrincipal) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (!_gravandoAudio)
          OutlinedButton.icon(
            onPressed: _existeAcaoEmAndamento ? null : _iniciarGravacaoRelato,
            icon: const Icon(Icons.mic_outlined),
            label: Text(
              _possuiAudioRelato ? 'Gravar novamente' : 'Iniciar gravação',
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
                color: _reproduzindoAudio ? Colors.red : corPrincipal,
              ),
            ),
          ),
        if (_possuiAudioRelato && !_gravandoAudio)
          OutlinedButton.icon(
            onPressed:
                _existeAcaoEmAndamento ? null : _removerAudioRelato,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remover áudio'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _existeAcaoEmAndamento ? null : _transcreverRelato,
          icon: _transcrevendoRelato
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.transcribe_outlined),
          label: Text(
            _transcrevendoRelato ? 'Transcrevendo...' : 'Transcrever áudio',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: corPrincipal,
            side: BorderSide(color: corPrincipal),
          ),
        ),
      ],
    );
  }

  Widget _audioInfoWidget(Color corPrincipal) {
    if (!_possuiAudioRelato) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          const Text(
            'Manter áudio salvo',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          Switch(
            value: _audioMantido,
            activeTrackColor: corPrincipal.withValues(alpha: 0.4),
            activeThumbColor: corPrincipal,
            onChanged: _existeAcaoEmAndamento
                ? null
                : (value) {
                    _audioMantido = value;
                    _triggerRebuild();
                  },
          ),
        ],
      ),
    );
  }

  Widget _secaoArtigosSugeridos() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBEAFE), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.menu_book_outlined, size: 18, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text(
                'INDICAÇÕES DE ARTIGOS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2563EB),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _artigosSugeridos,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botaoSalvar(Color corPrincipal) {
    final salvando = ref.watch(_salvandoProvider);
    return FilledButton.icon(
      onPressed: salvando ? null : _salvarSessao,
      icon: salvando
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.save_outlined),
      label: Text(salvando ? 'Salvando...' : 'Salvar sessão'),
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

