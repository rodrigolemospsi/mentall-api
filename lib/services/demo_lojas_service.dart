import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_ce/hive.dart';

import '../models/compromisso.dart';
import '../models/paciente.dart';
import '../models/perfil_profissional.dart';
import '../models/sessao.dart';
import 'compromisso_service.dart';
import 'encryption_service.dart';
import 'logger.dart';
import 'paciente_service.dart';
import 'perfil_profissional_service.dart';
import 'sessao_service.dart';

/// Semeia um conjunto de dados fictícios para gerar as **capturas de tela**
/// das lojas (Google Play / App Store).
///
/// Só executa quando compilado com `--dart-define=DEMO_LOJAS=true`, portanto
/// **não** afeta a produção (sem a flag, o método retorna imediatamente).
class DemoLojasService {
  static const bool ativoPorPadrao = bool.fromEnvironment('DEMO_LOJAS');
  static const String _flagKey = 'demo_lojas_criado';
  static const String fotoHelenaAsset =
      'assets/images/paciente_mulher_negra.jpeg';

  static const int totalPacientes = 23;
  static const int agendamentosHoje = 7;
  // Pago: 20 x R$ 289,00 = R$ 5.780,00. Pendente: 2 x R$ 190,00 = R$ 380,00.
  static const double valorPago = 289.0;
  static const int sessoesPagas = 20;
  static const double valorPendente = 190.0;
  static const int sessoesPendentes = 2;

  final EncryptionService encryption;
  final Future<String> Function()? fotoLoader;
  final bool ativo;

  late final PacienteService _pacientes;
  late final SessaoService _sessoes;
  late final CompromissoService _compromissos;
  late final PerfilProfissionalService _perfil;

  DemoLojasService({
    required this.encryption,
    this.fotoLoader,
    bool? ativo,
  }) : ativo = ativo ?? ativoPorPadrao {
    _pacientes = PacienteService(encryption: encryption);
    _sessoes = SessaoService(encryption: encryption);
    _compromissos = CompromissoService(encryption: encryption);
    _perfil = PerfilProfissionalService(encryption: encryption);
  }

  Box<String> get _box => Hive.box<String>('app_config');

  static const List<String> nomes = [
    'Ana Beatriz Souza',
    'Bruno Carvalho',
    'Camila Ferreira',
    'Diego Almeida',
    'Eduarda Lima',
    'Felipe Moraes',
    'Gabriela Rocha',
    'Henrique Dias',
    'Isabela Nunes',
    'João Pedro Martins',
    'Karina Ribeiro',
    'Lucas Barbosa',
    'Mariana Castro',
    'Nicolas Prado',
    'Olívia Mendes',
    'Paulo Ricardo',
    'Queila Santos',
    'Rafael Teixeira',
    'Sabrina Gomes',
    'Thiago Araújo',
    'Vitória Campos',
    'Wagner Freitas',
    'Yasmin Correia',
  ];

  Future<void> semearSeNecessario() async {
    if (!ativo) return;
    if (_box.get(_flagKey) == 'true') return;
    try {
      await _semearPerfil();
      final ids = await _semearPacientes();
      await _semearFinanceiro(ids);
      await _semearAgenda(ids);
      await _box.put(_flagKey, 'true');
      Log.info('DEMO_LOJAS: dados de demonstração semeados.');
    } catch (e) {
      Log.erro(e, contexto: 'DemoLojasService.semearSeNecessario');
    }
  }

  Future<void> _semearPerfil() async {
    String foto = '';
    try {
      final loader = fotoLoader;
      if (loader != null) {
        foto = await loader();
      } else {
        final byteData = await rootBundle.load(fotoHelenaAsset);
        foto = base64Encode(byteData.buffer.asUint8List());
      }
    } catch (e) {
      Log.erro(e, contexto: 'DemoLojasService._semearPerfil (foto)');
    }

    await _perfil.salvarPerfil(PerfilProfissional(
      id: 'demo-helena',
      nome: 'Helena Martins',
      registroProfissional: '06/123456',
      abordagemClinica: 'Integrativa',
      termoPessoaAtendida: 'paciente',
      fotoBase64: foto,
      tratamento: 'feminino',
      crpVerificado: true,
    ));
  }

  Future<List<String>> _semearPacientes() async {
    final ids = <String>[];
    for (var i = 0; i < totalPacientes; i++) {
      final id = 'demo-pac-$i';
      ids.add(id);
      await _pacientes.adicionarPaciente(Paciente(
        id: id,
        nome: nomes[i],
        dataNascimento: DateTime(1985 + (i % 15), (i % 12) + 1, (i % 27) + 1),
        contato: '(11) 9${(80000000 + i * 137).toString()}',
        tratamento: i.isEven ? 'feminino' : 'masculino',
        tipoAtendimento: 'Particular',
        dataCadastro: DateTime.now().subtract(Duration(days: 30 + i * 5)),
      ));
    }
    return ids;
  }

  Future<void> _semearFinanceiro(List<String> ids) async {
    final now = DateTime.now();
    for (var i = 0; i < sessoesPagas; i++) {
      final data = DateTime(now.year, now.month, (i % 25) + 1, 14, 0);
      if (i == 0) {
        // Sessão "com IA" (Ana) — conteúdo rico para a captura de tela.
        await _sessoes.adicionarSessao(Sessao(
          id: 'demo-ia-sessao',
          pacienteId: ids[0],
          numeroSessao: 1,
          data: data,
          transcricaoRelato: _transcricaoIa,
          relatoPosSessao: _relatoIa,
          eventosImportantes: _sinteseIa,
          pensamentosAutomaticos: _formulacaoIa,
          intervencoes: _intervencoesIa,
          planoProximaSessao: _planoIa,
          apontamentosCopiloto: _apontamentosIa,
          geradoComIa: true,
          statusProcessamento: 'transcrito',
          origemRelato: 'transcricao',
          revisadoPeloProfissional: true,
          valorSessao: valorPago,
          statusPagamento: 'pago',
          dataPagamento: data,
        ));
        continue;
      }
      await _sessoes.adicionarSessao(Sessao(
        id: 'demo-fin-pago-$i',
        pacienteId: ids[i % ids.length],
        numeroSessao: 1,
        data: data,
        statusProcessamento: 'manual',
        valorSessao: valorPago,
        statusPagamento: 'pago',
        dataPagamento: data,
      ));
    }
    for (var i = 0; i < sessoesPendentes; i++) {
      await _sessoes.adicionarSessao(Sessao(
        id: 'demo-fin-pend-$i',
        pacienteId: ids[i % ids.length],
        numeroSessao: 1,
        data: DateTime(now.year, now.month, 20 + i, 15, 0),
        statusProcessamento: 'manual',
        valorSessao: valorPendente,
        statusPagamento: 'pendente',
      ));
    }
  }

  Future<void> _semearAgenda(List<String> ids) async {
    final now = DateTime.now();
    const horas = [8, 9, 10, 11, 14, 15, 16];
    for (var i = 0; i < agendamentosHoje; i++) {
      await _compromissos.adicionar(Compromisso(
        id: 'demo-ag-$i',
        pacienteId: ids[i % ids.length],
        dataHoraInicio: DateTime(now.year, now.month, now.day, horas[i], 0),
        titulo: 'Sessão',
        status: 'agendado',
      ));
    }
  }

  static const String _transcricaoIa =
      'Ana iniciou a sessão relatando que a semana foi um pouco mais leve do que '
      'as anteriores. Contou que conseguiu organizar melhor as demandas do '
      'trabalho e que, em dois momentos de sobrecarga, parou e respirou antes de '
      'responder. Referiu que ainda sente ansiedade antes das reuniões, mas em '
      'intensidade menor.\n\n'
      'Trouxe um episódio em que recebeu uma crítica da liderança e, em vez de '
      'assumir imediatamente que havia falhado, pediu detalhes e percebeu que a '
      'observação era pontual e construtiva. Disse ter sentido alívio e mais '
      'confiança para seguir.\n\n'
      'Relatou também que voltou a caminhar duas vezes na semana e que isso '
      'ajudou no sono. Mencionou que os pensamentos de autocobrança ainda '
      'aparecem, mas que agora consegue questioná-los com mais frequência.';

  static const String _relatoIa =
      'A paciente chega à sessão com melhora subjetiva da ansiedade. Reconhece '
      'avanço na organização das demandas e na pausa antes de reagir a '
      'estressores. Destaca um episódio de feedback no trabalho em que '
      'conseguiu avaliar a crítica de forma objetiva, sem catastrofizar.\n\n'
      'Mantém autocrítica, porém com menor intensidade e maior capacidade de '
      'questionamento dos pensamentos automáticos. Retomou atividade física e '
      'observou impacto positivo no sono.';

  static const String _sinteseIa =
      'Evolução positiva em relação às sessões anteriores. Redução da '
      'intensidade ansiosa e maior repertório de regulação emocional. O '
      'episódio de feedback no trabalho marcou a consolidação da reestruturação '
      'cognitiva iniciada nas semanas anteriores.';

  static const String _formulacaoIa =
      'Crença central de valor pessoal atrelado ao desempenho. Pensamentos '
      'automáticos do tipo "se errar, serei julgada" foram identificados e '
      'reavaliados à luz das evidências. A resposta adaptativa ganhou espaço em '
      'situações de avaliação.';

  static const String _intervencoesIa =
      'Reestruturação cognitiva do episódio de feedback; psicoeducação sobre '
      'ansiedade antecipatória; reforço do registro de pensamentos; '
      'planejamento de pausas durante a jornada.';

  static const String _planoIa =
      'Manter o registro de pensamentos nos dias de reunião; ampliar as pausas '
      'conscientes para os períodos de maior demanda; retomar a caminhada três '
      'vezes na semana.';

  static const String _apontamentosIa =
      'Boa adesão às tarefas e insight crescente. Monitorar possíveis recaídas '
      'em semanas de pico de trabalho e reforçar a diferenciação entre '
      'desempenho e valor pessoal.';
}
