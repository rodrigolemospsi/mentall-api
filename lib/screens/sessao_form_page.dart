import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
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
import '../utils/mentall_colors.dart';
import '../utils/raio.dart';
import '../widgets/campo_texto_widget.dart';
import '../widgets/secao_campos_clinicos_widget.dart';
import '../widgets/secao_formulario.dart';
import '../widgets/sessao_artigos_sugeridos.dart';
import '../widgets/sessao_audio_controls.dart';
import '../widgets/sessao_form_widgets.dart';
import '../utils/tipografia.dart';

final _salvandoProvider = StateProvider<bool>((ref) => false);
final _dataSessaoProvider = StateProvider<DateTime>((ref) => DateTime.now());
final _formRebuildProvider = StateProvider<int>((ref) => 0);
final _statusProcessamentoProvider = StateProvider<String>((ref) => 'manual');
final _revisadoPeloProfissionalProvider = StateProvider<bool>((ref) => false);
final _geradoComIaProvider = StateProvider<bool>((ref) => false);
final _dataProcessamentoIaProvider = StateProvider<DateTime?>((ref) => null);
final _avisoInvalidacaoTranscricaoExibidoProvider = StateProvider<bool>((ref) => false);
final _audioMantidoProvider = StateProvider<bool>((ref) => false);
final _origemRelatoProvider = StateProvider<String>((ref) => 'manual');
final _modoEdicaoProvider = StateProvider<bool>((ref) => false);
final _valorSessaoProvider = StateProvider<double>((ref) => 0.0);
final _statusPagamentoProvider = StateProvider<String>((ref) => 'pendente');
final _dataPagamentoProvider = StateProvider<DateTime?>((ref) => null);
final _metodoPagamentoProvider = StateProvider<String>((ref) => '');
final _progressoSintomasProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);
final _progressoMetasProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);
final _progressoGeralProvider = StateProvider<String>((ref) => '');
final _progressoTendenciaProvider = StateProvider<String>((ref) => 'estavel');
final _progressoGerandoProvider = StateProvider<bool>((ref) => false);
final _buscandoArtigosProvider = StateProvider<bool>((ref) => false);

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
  final TextEditingController _planoProximaSessaoController =
      TextEditingController();
  final TextEditingController _valorController = TextEditingController();

  late String _sessaoId;
  late int _numeroSessao;

  Timer? _timerGravacao;

  static const Duration _duracaoMaximaAudio = Duration(minutes: 5);

  bool get _transcrevendoRelato => ref.read(transcrevendoRelatoProvider);
  set _transcrevendoRelato(bool v) => ref.read(transcrevendoRelatoProvider.notifier).state = v;

  bool get _gerandoSinteseIa => ref.read(gerandoSinteseIaProvider);
  set _gerandoSinteseIa(bool v) => ref.read(gerandoSinteseIaProvider.notifier).state = v;

  String get _statusProcessamento => ref.read(_statusProcessamentoProvider);
  set _statusProcessamento(String v) => ref.read(_statusProcessamentoProvider.notifier).state = v;

  String get _erroProcessamentoIa => ref.read(erroProcessamentoIaProvider);
  set _erroProcessamentoIa(String v) => ref.read(erroProcessamentoIaProvider.notifier).state = v;

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

  String get _artigosSugeridos => ref.read(artigosSugeridosProvider);
  set _artigosSugeridos(String v) => ref.read(artigosSugeridosProvider.notifier).state = v;

  bool get _buscandoArtigos => ref.read(_buscandoArtigosProvider);
  set _buscandoArtigos(bool v) => ref.read(_buscandoArtigosProvider.notifier).state = v;

  bool get _modoEdicao => ref.read(_modoEdicaoProvider);
  set _modoEdicao(bool v) => ref.read(_modoEdicaoProvider.notifier).state = v;

  double get _valorSessao => ref.read(_valorSessaoProvider);
  set _valorSessao(double v) => ref.read(_valorSessaoProvider.notifier).state = v;

  String get _statusPagamento => ref.read(_statusPagamentoProvider);
  set _statusPagamento(String v) => ref.read(_statusPagamentoProvider.notifier).state = v;

  DateTime? get _dataPagamento => ref.read(_dataPagamentoProvider);
  set _dataPagamento(DateTime? v) => ref.read(_dataPagamentoProvider.notifier).state = v;

  String get _metodoPagamento => ref.read(_metodoPagamentoProvider);
  set _metodoPagamento(String v) => ref.read(_metodoPagamentoProvider.notifier).state = v;

  bool get _controleFinanceiroAtivo =>
      ref.read(configuracoesServiceProvider).controleFinanceiroAtivo;

  List<Map<String, dynamic>> get _progressoSintomas =>
      ref.read(_progressoSintomasProvider);
  set _progressoSintomas(List<Map<String, dynamic>> v) =>
      ref.read(_progressoSintomasProvider.notifier).state = v;

  set _progressoMetas(List<Map<String, dynamic>> v) =>
      ref.read(_progressoMetasProvider.notifier).state = v;

  String get _progressoAvaliacaoGeral =>
      ref.read(_progressoGeralProvider);
  set _progressoAvaliacaoGeral(String v) =>
      ref.read(_progressoGeralProvider.notifier).state = v;

  String get _progressoTendencia =>
      ref.read(_progressoTendenciaProvider);
  set _progressoTendencia(String v) =>
      ref.read(_progressoTendenciaProvider.notifier).state = v;

  bool get _progressoGerando =>
      ref.read(_progressoGerandoProvider);
  set _progressoGerando(bool v) =>
      ref.read(_progressoGerandoProvider.notifier).state = v;

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

  bool get _reproduzindoAudio => ref.read(reproduzindoAudioProvider);
  set _reproduzindoAudio(bool valor) =>
      ref.read(reproduzindoAudioProvider.notifier).state = valor;

  String get _audioRelatoPath => ref.read(audioRelatoPathProvider);

  String get _audioRelatoBase64 => ref.read(audioRelatoBase64Provider);

  String _ultimaTranscricaoControlada = '';
  bool _alteracaoProgramaticaTranscricao = false;

  bool get _editando => widget.sessaoExistente != null;

  bool get _existeAcaoEmAndamento {
    return ref.read(gravandoAudioProvider) ||
        _transcrevendoRelato ||
        _gerandoSinteseIa ||
        ref.read(preparandoAudioProvider);
  }

  bool _descarteConfirmado = false;

  bool _temAlteracoesNaoSalvas() {
    if (_descarteConfirmado) return false;
    if (_modoEdicao) return true;

    if (_editando) return false;

    return _relatoPosSessaoController.text.trim().isNotEmpty ||
        _transcricaoRelatoController.text.trim().isNotEmpty ||
        _sinteseController.text.trim().isNotEmpty ||
        _formulacaoController.text.trim().isNotEmpty ||
        _intervencoesController.text.trim().isNotEmpty ||
        _apontamentosController.text.trim().isNotEmpty ||
        _possuiAudioRelato;
  }

  String get _termoSingular {
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    return perfil?.termoSingular ?? 'paciente';
  }

  String get _termoSingularCapitalizado {
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    return perfil?.termoSingularCapitalizado ?? 'Paciente';
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
    return ref.read(audioRelatoPathProvider).trim().isNotEmpty ||
        ref.read(audioRelatoBase64Provider).trim().isNotEmpty;
  }

  bool get _possuiAudioRelatoBase64 {
    return ref.read(audioRelatoBase64Provider).trim().isNotEmpty;
  }

  bool get _possuiTranscricaoRelato {
    return _transcricaoRelatoController.text.trim().isNotEmpty;
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

        _relatoPosSessaoController.text = sessao.relatoPosSessao;
        _transcricaoRelatoController.text = sessao.transcricaoRelato;
        _sinteseController.text = _concatenarSintese(sessao);
        _formulacaoController.text = _concatenarFormulacao(sessao);
        _intervencoesController.text = sessao.intervencoes;
        _apontamentosController.text = sessao.apontamentosCopiloto;
        _planoProximaSessaoController.text = sessao.planoProximaSessao;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(_dataSessaoProvider.notifier).state = sessao.data;
          ref.read(audioRelatoPathProvider.notifier).state = sessao.audioRelatoPath;
          ref.read(audioRelatoBase64Provider.notifier).state = sessao.audioRelatoBase64;
          _dataProcessamentoIa = sessao.dataProcessamentoIa;
          _geradoComIa = sessao.geradoComIa;
          _statusProcessamento = sessao.statusProcessamento;
          _audioMantido = sessao.audioMantido;
          _revisadoPeloProfissional = sessao.revisadoPeloProfissional;
          _erroProcessamentoIa = sessao.erroProcessamentoIa;
          _artigosSugeridos = sessao.artigosSugeridos;
          _origemRelato = sessao.origemRelato;
          _modoEdicao = false;
          ref.read(_valorSessaoProvider.notifier).state = sessao.valorSessao;
          ref.read(_statusPagamentoProvider.notifier).state = sessao.statusPagamento;
          ref.read(_dataPagamentoProvider.notifier).state = sessao.dataPagamento;
          ref.read(_metodoPagamentoProvider.notifier).state = sessao.metodoPagamento;
          _valorController.text = sessao.valorSessao > 0
              ? sessao.valorSessao.toStringAsFixed(2).replaceAll('.', ',')
              : '';
          _triggerRebuild();
        });
      } else {
        _resetarEstadoSessao();
        _sessaoId = DateTime.now().millisecondsSinceEpoch.toString();
        _numeroSessao = _sessaoService.proximoNumeroSessao(widget.paciente.id);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(_dataSessaoProvider.notifier).state = DateTime.now();
          _modoEdicao = true;

          final config = ref.read(configuracoesServiceProvider);
          final pacoteService = ref.read(pacoteServiceProvider);
          final sessoesRestantes = pacoteService.totalSessoesRestantes(widget.paciente.id);
          final temPacoteAtivo = sessoesRestantes > 0;

          if (temPacoteAtivo) {
            final valorPorSessao = pacoteService.valorPorSessaoAtivo(widget.paciente.id) ?? 0.0;
            ref.read(_valorSessaoProvider.notifier).state = valorPorSessao;
            ref.read(_statusPagamentoProvider.notifier).state = 'pacote';
          } else {
            double valorInicial = widget.paciente.valorSessao;
            if (valorInicial <= 0) {
              valorInicial = config.valorPadraoSessao;
            }
            ref.read(_valorSessaoProvider.notifier).state = valorInicial;
            ref.read(_statusPagamentoProvider.notifier).state = 'pendente';
          }
          ref.read(_dataPagamentoProvider.notifier).state = null;
          ref.read(_metodoPagamentoProvider.notifier).state = '';
          _valorController.text = ref.read(_valorSessaoProvider) > 0
              ? ref.read(_valorSessaoProvider).toStringAsFixed(2).replaceAll('.', ',')
              : '';

          _triggerRebuild();
        });
      }

      _ultimaTranscricaoControlada = _transcricaoRelatoController.text;
      _transcricaoRelatoController.addListener(_aoAlterarTranscricaoRelato);
    } catch (e, stack) {
      _erroInicializacao = kDebugMode ? '$e\n$stack' : '$e';
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
    _planoProximaSessaoController.dispose();
    _valorController.dispose();

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
          duration: Duration(seconds: 4),
          content: Text(
            'A transcrição foi alterada. A síntese e a revisão foram invalidadas. '
            'Os campos clínicos foram preservados — gere nova síntese se necessário.',
          ),
        ),
      );
    }
  }

  void _invalidarIaERevisaoPorAlteracaoDaTranscricao() {
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(audioRelatoPathProvider.notifier).state = '';
      ref.read(audioRelatoBase64Provider.notifier).state = '';
      ref.read(gravandoAudioProvider.notifier).state = false;
      ref.read(audioPausadoProvider.notifier).state = false;
      ref.read(reproduzindoAudioProvider.notifier).state = false;
      ref.read(duracaoGravacaoProvider.notifier).state = Duration.zero;
      ref.read(erroAudioProvider.notifier).state = '';
      ref.read(transcrevendoRelatoProvider.notifier).state = false;
      ref.read(gerandoSinteseIaProvider.notifier).state = false;
      ref.read(_statusProcessamentoProvider.notifier).state = 'manual';
      ref.read(erroProcessamentoIaProvider.notifier).state = '';
      ref.read(_revisadoPeloProfissionalProvider.notifier).state = false;
      ref.read(_geradoComIaProvider.notifier).state = false;
      ref.read(_dataProcessamentoIaProvider.notifier).state = null;
      ref.read(_avisoInvalidacaoTranscricaoExibidoProvider.notifier).state = false;
      ref.read(_audioMantidoProvider.notifier).state = false;
      ref.read(_origemRelatoProvider.notifier).state = 'manual';
      ref.read(artigosSugeridosProvider.notifier).state = '';
      ref.read(_salvandoProvider.notifier).state = false;
      ref.read(_formRebuildProvider.notifier).state = 0;
    });
  }

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
            ref.read(duracaoGravacaoProvider) + const Duration(seconds: 1);
        ref.read(duracaoGravacaoProvider.notifier).state = novaDuracao;
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

  String _normalizarAudioBase64(String valor) {
    final texto = valor.trim();

    if (texto.startsWith('data:') && texto.contains(',')) {
      return texto.split(',').last.trim();
    }

    return texto;
  }

  Future<Source?> _criarFonteAudioPorCaminho(String caminhoAudio) async {
    final caminho = caminhoAudio.trim();

    if (caminho.isEmpty) {
      return null;
    }

    if (caminho.startsWith('http') || caminho.startsWith('blob:')) {
      return UrlSource(caminho);
    }

    try {
      final tempPath = await AudioRelatoService.prepararAudioParaPlayback(caminho);
      return DeviceFileSource(tempPath);
    } catch (_) {
      return null;
    }
  }

  Source? _criarFonteAudioBase64() {
    final base64Audio = _normalizarAudioBase64(ref.read(audioRelatoBase64Provider));

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

      _registrarAuditoria('Gravação de áudio', 'Início da gravação do relato - sessão $_numeroSessao');

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
              ? 'Gravação finalizada e salva.'
              : (kIsWeb
                  ? 'Gravação finalizada, mas o backup Base64 não foi gerado.'
                  : 'Gravação finalizada.'),
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

      ref.read(preparandoAudioProvider.notifier).state = true;
      _triggerRebuild();

      try {
        if (devePreferirBase64) {
          fonteAudio = _criarFonteAudioBase64();
        } else {
          fonteAudio = await _criarFonteAudioPorCaminho(caminhoAudio) ??
              _criarFonteAudioBase64();
        }
      } finally {
        ref.read(preparandoAudioProvider.notifier).state = false;
        if (mounted) _triggerRebuild();
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
            ? await _criarFonteAudioPorCaminho(caminhoAudio)
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

    if (_geradoComIa || _sinteseController.text.isNotEmpty ||
        _formulacaoController.text.isNotEmpty ||
        _intervencoesController.text.isNotEmpty ||
        _apontamentosController.text.isNotEmpty) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sobrescrever conteúdo?'),
          content: const Text(
            'Os campos clínicos já possuem conteúdo. '
            'A síntese com IA substituirá o que foi escrito. Continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
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

        _preencherController(
          controller: _sinteseController,
          texto: resultado.sinteseClinica,
        );

        _preencherController(
          controller: _formulacaoController,
          texto: resultado.formulacaoClinica,
        );

        _preencherController(
          controller: _intervencoesController,
          texto: resultado.intervencoes,
        );

        _preencherController(
          controller: _apontamentosController,
          texto: resultado.apontamentosCopiloto,
        );

        _preencherController(
          controller: _planoProximaSessaoController,
          texto: resultado.planoProximaSessao,
        );

        _artigosSugeridos = '';

        _gerandoSinteseIa = false;
        _geradoComIa = true;
        _dataProcessamentoIa = DateTime.now();
        _statusProcessamento = 'ia_processada';
        _revisadoPeloProfissional = false;
        _erroProcessamentoIa = '';
        _avisoInvalidacaoTranscricaoExibido = false;
        _triggerRebuild();

        _registrarAuditoria('Síntese gerada por IA', 'IA gerou síntese clínica - sessão $_numeroSessao');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Síntese clínica e campos estruturados gerados para revisão.',
            ),
          ),
        );

        final sugerirArtigos = ref.read(configuracoesServiceProvider).sugerirArtigos;
        if (sugerirArtigos && resultado.temasPesquisa.isNotEmpty) {
          _buscarArtigosEmBackground(
            resultado.temasPesquisa,
            resultado.relatoClinicoOrganizado,
            resultado.sinteseClinica,
          );
        }

        if (_numeroSessao > 1) {
          _gerarProgressoAutomatico();
        }

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
          'Serviço de IA temporariamente indisponível. Tente novamente em instantes.';
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
    ref.read(erroAudioProvider.notifier).state = '';

    _registrarAuditoria('Revisão profissional', 'Sessão $_numeroSessao marcada como revisada');

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
        sessao.planoProximaSessao = _planoProximaSessaoController.text.trim();
        sessao.apontamentosCopiloto = _apontamentosController.text.trim();

        sessao.audioRelatoPath = _audioRelatoPath;
        sessao.audioRelatoBase64 = kIsWeb ? _audioRelatoBase64 : '';
        sessao.dataProcessamentoIa = _dataProcessamentoIa;
        sessao.geradoComIa = _geradoComIa;
        sessao.statusProcessamento = _statusProcessamento;
        sessao.audioMantido = _audioMantido;
        sessao.revisadoPeloProfissional = _revisadoPeloProfissional;
        sessao.erroProcessamentoIa = _erroProcessamentoIa;
        sessao.origemRelato = _origemRelato;
        sessao.artigosSugeridos = _artigosSugeridos;
        sessao.valorSessao = _valorSessao;
        sessao.statusPagamento = _statusPagamento;
        sessao.dataPagamento = _statusPagamento == 'pago' ? _dataPagamento : null;
        sessao.metodoPagamento = _statusPagamento == 'pago' ? _metodoPagamento : '';

        await _sessaoService.atualizarSessao(sessao);
        if (_statusPagamento == 'pacote') {
          ref.read(pacoteServiceProvider).consumirSessao(widget.paciente.id);
        }
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
          planoProximaSessao: _planoProximaSessaoController.text.trim(),
          apontamentosCopiloto: _apontamentosController.text.trim(),
          audioRelatoPath: _audioRelatoPath,
          audioRelatoBase64: kIsWeb ? _audioRelatoBase64 : '',
          dataProcessamentoIa: _dataProcessamentoIa,
          statusProcessamento: _statusProcessamento,
          audioMantido: _audioMantido,
          revisadoPeloProfissional: _revisadoPeloProfissional,
          erroProcessamentoIa: _erroProcessamentoIa,
          origemRelato: _origemRelato,
          artigosSugeridos: _artigosSugeridos,
          valorSessao: _valorSessao,
          statusPagamento: _statusPagamento,
          dataPagamento: _statusPagamento == 'pago' ? _dataPagamento : null,
          metodoPagamento: _statusPagamento == 'pago' ? _metodoPagamento : '',
        );

        await _sessaoService.adicionarSessao(novaSessao);
        if (_statusPagamento == 'pacote') {
          ref.read(pacoteServiceProvider).consumirSessao(widget.paciente.id);
        }
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

  @override
  Widget build(BuildContext context) {
    if (_erroInicializacao != null) {
      return Scaffold(
        backgroundColor: context.corFundo,
        appBar: AppBar(
          title: const Text('Erro'),
          backgroundColor: context.corError,
          foregroundColor: context.corOnError,
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Icons.error_outline, color: context.corError, size: 48),
            const SizedBox(height: 16),
            Text(
              'Não foi possível abrir o prontuário',
              style: TextStyle(
                fontSize: Tipografia.xl,
                fontWeight: FontWeight.bold,
                color: context.corError,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Isso pode ser causado por dados incompatíveis de uma versão anterior do app. Tente limpar os dados do aplicativo nas configurações do Android.',
              style: TextStyle(color: context.corTextoSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.corError.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Raio.md),
              ),
              child: Text(
                _erroInicializacao!,
                style: TextStyle(
                  fontSize: Tipografia.sm,
                  color: context.corTextoBody,
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
                backgroundColor: context.corError,
                foregroundColor: context.corOnError,
              ),
            ),
          ],
        ),
      );
    }

    ref.watch(_formRebuildProvider);
    final configuracao = _configuracaoAbordagem;

    return PopScope(
      canPop: !_temAlteracoesNaoSalvas(),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirmar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Descartar alterações?'),
            content: const Text('As alterações não salvas serão perdidas.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Continuar editando'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Descartar'),
              ),
            ],
          ),
        );
        if (confirmar == true && context.mounted) {
          _descarteConfirmado = true;
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      backgroundColor: context.corFundo,
      appBar: AppBar(
        title: Text(_editando ? 'Sessão $_numeroSessao' : 'Nova sessão'),
        backgroundColor: context.corPrimaria,
        foregroundColor: context.corOnPrimaria,
        actions: _editando
            ? [
                if (_modoEdicao)
                  Semantics(
                    label: 'Salvar sessão',
                    child: IconButton(
                      tooltip: 'Salvar',
                      icon: const Icon(Icons.check),
                      onPressed: _salvarSessao,
                    ),
                  ),
                IconButton(
                  tooltip: 'Exportar PDF',
                  icon: const Icon(Icons.file_download_outlined),
                  onPressed: _exportarSessao,
                ),
                if (!_modoEdicao)
                  TextButton.icon(
                    onPressed: () {
                      _modoEdicao = true;
                      _triggerRebuild();
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar'),
                  ),
              ]
            : null,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _cardCabecalho(configuracao),
              const SizedBox(height: 16),
              IgnorePointer(
                ignoring: _editando && !_modoEdicao,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: (_editando && !_modoEdicao) ? 0.85 : 1.0,
                  child: Column(
                  children: [
                    _cardInformacoesGerais(),
                    const SizedBox(height: 16),
                    _secaoRelatoIa(),
                    if (_editando || _geradoComIa) ...[
                      const SizedBox(height: 16),
                      SecaoCamposClinicosWidget(
                        configuracao: configuracao,
                        sinteseController: _sinteseController,
                        formulacaoController: _formulacaoController,
                        intervencoesController: _intervencoesController,
                        apontamentosController: _apontamentosController,
                        planoProximaSessaoController: _planoProximaSessaoController,
                      ),
                    ],
                    if (_buscandoArtigos) ...[
                      const SizedBox(height: 16),
                      _cardBuscandoArtigos(),
                    ] else if (_artigosSugeridos.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const ArtigosSugeridosCard(),
                    ],
                    if (_controleFinanceiroAtivo) ...[
                      const SizedBox(height: 16),
                      _secaoFinanceira(),
                    ],
                    if (_geradoComIa && _numeroSessao >= 2) ...[
                      const SizedBox(height: 16),
                      _secaoProgresso(),
                    ],
                  ],
                ),
              ),
              ),
              if (_modoEdicao || (!_editando && _possuiTranscricaoRelato)) ...[
                const SizedBox(height: 16),
                _botaoSalvar(),
              ],
              const SizedBox(height: 24),
            ],
          ),
          if (_editando && !_modoEdicao)
            Positioned.fill(
              child: Semantics(
                button: true,
                label: 'Toque duas vezes para editar esta sessão',
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _mostrarDialogoEditar,
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }

  Future<void> _mostrarDialogoEditar() async {
    final editar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sessão bloqueada'),
        content: const Text('Esta sessão está em modo de visualização. '
            'Deseja habilitar a edição? Ao editar, a síntese por IA e a revisão poderão ser invalidadas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Editar'),
          ),
        ],
      ),
    );
    if (editar == true) {
      _modoEdicao = true;
      _triggerRebuild();
    }
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
        borderRadius: BorderRadius.circular(Raio.xxl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          'SESSÃO $_numeroSessao',
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _cardInformacoesGerais() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raio.xxl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: _selecionarData,
              borderRadius: BorderRadius.circular(Raio.md),
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
              borderRadius: BorderRadius.circular(Raio.md),
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

  Widget _secaoRelatoIa() {
    return SecaoFormulario(
      children: [
        const TimerGravacaoWidget(),
        const ProcessamentoIaWidget(),
        ErroProcessamentoIaWidget(
          onLimparErro: _limparErroProcessamento,
        ),
        ErroAudioWidget(
          onLimparErro: _limparErroAudio,
        ),
        BotoesAudioWidget(
          existeAcaoEmAndamento: _existeAcaoEmAndamento,
          onGravar: _iniciarGravacaoRelato,
          onPausar: _pausarGravacaoRelato,
          onRetomar: _retomarGravacaoRelato,
          onFinalizar: _pararGravacaoRelato,
          onCancelar: _cancelarGravacaoRelato,
          onOuvirParar: _ouvirOuPararAudioRelato,
          onRemover: _removerAudioRelato,
        ),
        _audioInfoWidget(),
        if (_possuiAudioRelato && !_transcrevendoRelato) ...[
          const SizedBox(height: 12),
          Semantics(
            label: 'Transcrever áudio',
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _existeAcaoEmAndamento ? null : _transcreverRelato,
                icon: const Icon(Icons.subtitles_rounded),
                label: const Text('Transcrever com IA'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.corPrimaria,
                  foregroundColor: context.corOnPrimaria,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        CampoTextoWidget(
          controller: _transcricaoRelatoController,
          label: 'Transcrição',
        ),
        if (_possuiTranscricaoRelato) ...[
          const SizedBox(height: 12),
          Semantics(
            label: 'Gerar síntese',
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _existeAcaoEmAndamento ? null : _gerarSinteseComIa,
                icon: _gerandoSinteseIa
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.corOnPrimaria,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                label: Text(
                  _gerandoSinteseIa ? 'Gerando...' : 'Gerar síntese',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: context.corPrimaria,
                  foregroundColor: context.corOnPrimaria,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ],
        if (_geradoComIa) ...[
          const SizedBox(height: 12),
          CampoTextoWidget(
            controller: _relatoPosSessaoController,
            label: 'Relato clínico organizado',
          ),
        ],
        if (!_revisadoPeloProfissional && _geradoComIa) ...[
          const SizedBox(height: 4),
          Semantics(
            label: 'Marcar como revisado',
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _existeAcaoEmAndamento ? null : _marcarComoRevisado,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Marcar como revisado'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.corPrimaria,
                  foregroundColor: context.corOnPrimaria,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _audioInfoWidget() {
    if (!_possuiAudioRelato) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AudioMantidoSwitch(
        valor: _audioMantido,
        desabilitado: _existeAcaoEmAndamento,
        onChanged: (value) {
          _audioMantido = value;
          _triggerRebuild();
        },
      ),
    );
  }

  Future<void> _buscarArtigosEmBackground(
    List<dynamic> temasPesquisa,
    String relatoClinico,
    String sinteseClinica,
  ) async {
    _buscandoArtigos = true;
    _triggerRebuild();

    final contexto = [relatoClinico, sinteseClinica]
        .where((t) => t.trim().isNotEmpty)
        .join(' ');

    final artigos = await _iaClinicaService.gerarArtigos(
      temasPesquisa: temasPesquisa,
      contextoClinico: contexto,
    );

    if (!mounted) return;
    _buscandoArtigos = false;
    if (artigos != null && artigos.trim().isNotEmpty) {
      _artigosSugeridos = artigos;
    }
    _triggerRebuild();
  }

  Widget _cardBuscandoArtigos() {
    return const CardBuscandoArtigos();
  }

  Future<void> _gerarProgressoAutomatico() async {
    if (_progressoGerando) return;
    _progressoGerando = true;
    _triggerRebuild();

    try {
      final sessaoService = ref.read(sessaoServiceProvider);
      final sessoesAnteriores = sessaoService
          .listarSessoesRecentes(widget.paciente.id, limite: 5)
          .where((s) => s.id != _sessaoId)
          .map((s) => {
                'numero': s.numeroSessao,
                'sintese': s.eventosImportantes,
                'data': s.data.toIso8601String().substring(0, 10),
              })
          .toList();

      if (sessoesAnteriores.isEmpty) return;

      final resultado = await _iaClinicaService.gerarProgresso(
        pacienteId: widget.paciente.id,
        numeroSessao: _numeroSessao,
        sessoesAnteriores: sessoesAnteriores,
        sessaoAtual: {
          'sintese': _sinteseController.text.trim(),
          'relato': _relatoPosSessaoController.text.trim(),
          'intervencoes': _intervencoesController.text.trim(),
          'data': ref.read(_dataSessaoProvider).toIso8601String().substring(0, 10),
        },
        objetivosTerapeuticos: _obterObjetivosTerapeuticos(),
        queixaPrincipal: _obterQueixaPrincipal(),
        escalas: _obterEscalasRecentes(),
      );

      if (!mounted) return;

      if (resultado.sucesso) {
        _progressoSintomas = resultado.sintomas;
        _progressoMetas = resultado.metas;
        _progressoAvaliacaoGeral = resultado.avaliacaoGeral;
        _progressoTendencia = resultado.tendencia;

        ref.read(progressoServiceProvider).salvar(
              pacienteId: widget.paciente.id,
              sessaoId: _sessaoId,
              numeroSessao: _numeroSessao,
              sintomas: resultado.sintomas,
              metas: resultado.metas,
              avaliacaoGeral: resultado.avaliacaoGeral,
              tendencia: resultado.tendencia,
            );

        _registrarAuditoria('Progresso gerado por IA', 'IA gerou tracking de evolução - sessão $_numeroSessao');
      }

      _progressoGerando = false;
      _triggerRebuild();
    } catch (e) {
      _progressoGerando = false;
      _triggerRebuild();
    }
  }

  String _obterObjetivosTerapeuticos() {
    try {
      final avaliacao = ref.read(avaliacaoInicialServiceProvider).obterPorPaciente(widget.paciente.id);
      return avaliacao?.objetivosTerapeuticos ?? '';
    } catch (_) {
      return '';
    }
  }

  String _obterQueixaPrincipal() {
    try {
      final avaliacao = ref.read(avaliacaoInicialServiceProvider).obterPorPaciente(widget.paciente.id);
      return avaliacao?.queixaPrincipal ?? '';
    } catch (_) {
      return '';
    }
  }

  List<Map<String, dynamic>> _obterEscalasRecentes() {
    try {
      final escalas = ref.read(escalaServiceProvider).listarPorPaciente(widget.paciente.id);
      final agrupadas = <String, List<Map<String, dynamic>>>{};
      for (final e in escalas) {
        agrupadas.putIfAbsent(e.escalaId, () => []);
        agrupadas[e.escalaId]!.add({
          'data': e.dataAplicacao.toIso8601String().substring(0, 10),
          'pontuacao': e.pontuacao,
          'interpretacao': e.interpretacao,
        });
      }
      return agrupadas.entries.map((entry) => {
            'nome': _nomeEscala(entry.key),
            'datas': entry.value,
          }).toList();
    } catch (_) {
      return [];
    }
  }

  String _nomeEscala(String id) {
    const nomes = {
      'phq9': 'PHQ-9 (Depressão)',
      'gad7': 'GAD-7 (Ansiedade)',
      'dass21': 'DASS-21',
    };
    return nomes[id] ?? id;
  }

  Widget _secaoProgresso() {
    if (_progressoGerando) {
      return Card(
        margin: EdgeInsets.zero,
        color: context.corCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Raio.lg)),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('Gerando análise de evolução...', style: TextStyle(fontSize: Tipografia.smMd)),
            ],
          ),
        ),
      );
    }

    if (_progressoSintomas.isEmpty) return const SizedBox.shrink();

    final corTendencia = _corTendencia(_progressoTendencia);

    return Card(
      margin: EdgeInsets.zero,
      color: context.corCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Raio.lg)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: corTendencia, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Evolução Clínica',
                  style: TextStyle(fontSize: Tipografia.base, fontWeight: FontWeight.w700, color: context.corTextoHeading),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._progressoSintomas.take(4).map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        s['tendencia'] == 'melhora'
                            ? Icons.arrow_downward
                            : s['tendencia'] == 'piora'
                                ? Icons.arrow_upward
                                : Icons.remove,
                        size: 14,
                        color: s['tendencia'] == 'melhora'
                            ? context.corSuccess
                            : s['tendencia'] == 'piora'
                                ? context.corError
                                : context.corTextoMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${s['nome']} — ${s['intensidade']}/10',
                          style: TextStyle(fontSize: Tipografia.sm, color: context.corTextoBody),
                        ),
                      ),
                    ],
                  ),
                )),
            if (_progressoAvaliacaoGeral.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: corTendencia.withAlpha(15),
                  borderRadius: BorderRadius.circular(Raio.xxs),
                ),
                child: Row(
                  children: [
                    Icon(Icons.insights, size: 14, color: corTendencia),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _progressoAvaliacaoGeral,
                        style: TextStyle(fontSize: Tipografia.xs, color: corTendencia, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _corTendencia(String tendencia) {
    switch (tendencia) {
      case 'melhora':
        return context.corSuccess;
      case 'piora':
        return context.corError;
      case 'mista':
        return context.corWarning;
      default:
        return context.corScheduled;
    }
  }

  Widget _secaoFinanceira() {
    final pacoteService = ref.read(pacoteServiceProvider);
    final sessoesRestantes = pacoteService.totalSessoesRestantes(widget.paciente.id);
    final temPacoteAtivo = sessoesRestantes > 0;
    final ehPacote = _statusPagamento == 'pacote';

    return Card(
      margin: EdgeInsets.zero,
      color: context.corCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Raio.lg)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payments_outlined, color: context.corPrimaria, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Financeiro',
                  style: TextStyle(fontSize: Tipografia.base, fontWeight: FontWeight.w700, color: context.corTextoHeading),
                ),
              ],
            ),
            if (temPacoteAtivo) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: context.corPacote.withAlpha(20),
                  borderRadius: BorderRadius.circular(Raio.xs),
                  border: Border.all(color: context.corPacote.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 16, color: context.corPacote),
                    const SizedBox(width: 8),
                    Text(
                      'Pacote ativo: $sessoesRestantes ${sessoesRestantes == 1 ? 'sessão restante' : 'sessões restantes'}',
                      style: TextStyle(fontSize: Tipografia.sm, fontWeight: FontWeight.w600, color: context.corPacote),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            IgnorePointer(
              ignoring: ehPacote,
              child: TextField(
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor da sessão (R\$)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                controller: _valorController,
                onChanged: (v) {
                  final parsed = double.tryParse(v.replaceAll(',', '.'));
                  if (parsed != null) {
                    _valorSessao = parsed;
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _statusPagamento,
              decoration: const InputDecoration(
                labelText: 'Status do pagamento',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                const DropdownMenuItem(value: 'pendente', child: Text('Pendente')),
                const DropdownMenuItem(value: 'pago', child: Text('Pago')),
                const DropdownMenuItem(value: 'convenio', child: Text('Convênio')),
                if (temPacoteAtivo || ehPacote)
                  const DropdownMenuItem(value: 'pacote', child: Text('Pacote')),
              ],
              onChanged: (v) {
                if (v != null) {
                  _statusPagamento = v;
                  if (v == 'pago') {
                    _dataPagamento = DateTime.now();
                  } else if (v == 'pacote') {
                    _dataPagamento = null;
                    _metodoPagamento = '';
                    final valorPorSessao = pacoteService.valorPorSessaoAtivo(widget.paciente.id) ?? 0.0;
                    if (valorPorSessao > 0) {
                      _valorSessao = valorPorSessao;
                    }
                  } else {
                    _dataPagamento = null;
                    _metodoPagamento = '';
                  }
                  _triggerRebuild();
                }
              },
            ),
            if (_statusPagamento == 'pago') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _metodoPagamento.isEmpty ? null : _metodoPagamento,
                decoration: const InputDecoration(
                  labelText: 'Método de pagamento',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(value: 'pix', child: Text('Pix')),
                  DropdownMenuItem(value: 'dinheiro', child: Text('Dinheiro')),
                  DropdownMenuItem(value: 'cartao_credito', child: Text('Cartão de crédito')),
                  DropdownMenuItem(value: 'cartao_debito', child: Text('Cartão de débito')),
                  DropdownMenuItem(value: 'transferencia', child: Text('Transferência')),
                ],
                onChanged: (v) {
                  _metodoPagamento = v ?? '';
                  _triggerRebuild();
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _dataPagamento ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    cancelText: 'Cancelar',
                    confirmText: 'OK',
                  );
                  if (date != null) {
                    _dataPagamento = date;
                    _triggerRebuild();
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data do pagamento',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  child: Text(
                    _dataPagamento != null
                        ? '${_dataPagamento!.day.toString().padLeft(2, '0')}/${_dataPagamento!.month.toString().padLeft(2, '0')}/${_dataPagamento!.year}'
                        : 'Selecionar data',
                    style: TextStyle(
                      fontSize: Tipografia.base,
                      color: _dataPagamento != null ? context.corTextoBody : context.corTextoMuted,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _botaoSalvar() {
    final salvando = ref.watch(_salvandoProvider);
    return BotaoSalvarSessao(
      salvando: salvando,
      onPressed: _salvarSessao,
    );
  }
}

