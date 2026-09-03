import 'package:hive_ce/hive.dart';
import 'encrypted_service_mixin.dart';
import 'encryption_service.dart';

class ConfiguracoesService with EncryptedServiceMixin {
  @override
  final EncryptionService? encryption;

  ConfiguracoesService({this.encryption});

  static const String _boxName = 'app_config';

  static const String _kDuracaoSessaoMin = 'duracao_padrao_sessao_min';
  static const String _kLembretePadraoAtivado = 'lembrete_padrao_ativado';
  static const String _kAntecedenciaPadraoMin =
      'lembrete_antecedencia_padrao_min';
  static const String _kSugerirArtigos = 'ia_sugerir_artigos';
  static const String _kTemaEscuro = 'tema_escuro';
  static const String _kCanalLembretePadrao = 'canal_lembrete_padrao';
  static const String _kContratoTemplate = 'contrato_template';
  static const String _kValorPadraoSessao = 'valor_padrao_sessao';
  static const String _kControleFinanceiroAtivo = 'controle_financeiro_ativo';
  static const String _kDemoCriado = 'demo_criado';
  static const String _kBiometriaAtivada = 'biometria_ativada';
  static const String _kOnboardingConcluido = 'onboarding_concluido';
  static const String _kBackupFrequencia = 'backup_frequencia';
  static const String _kBackupLocal = 'backup_local';
  static const String _kUltimoBackupEm = 'backup_ultimo_em';

  static const String contratoPadrao = '''Este \u00e9 um espa\u00e7o de cuidado, escuta e respeito.

Compromissos
Psic\u00f3logo(a): ofere\u00e7o um atendimento \u00e9tico, acolhedor e sigiloso, respeitando sua singularidade e autonomia.
Paciente: comprometo-me a participar dos atendimentos com responsabilidade, pontualidade e comunica\u00e7\u00e3o sempre que houver d\u00favidas, imprevistos ou necessidade de remarca\u00e7\u00e3o.

Cancelamentos
Cancelamentos ou remarca\u00e7\u00f5es devem ser informados com pelo menos 24 horas de anteced\u00eancia.
Ap\u00f3s esse prazo, ou em caso de falta sem aviso, a sess\u00e3o poder\u00e1 ser cobrada integralmente.

Sigilo
Tudo o que for compartilhado ser\u00e1 preservado em confidencialidade, exceto nas situa\u00e7\u00f5es previstas em lei.

Consentimento
Ao preencher e aceitar este formul\u00e1rio, declaro estar ciente e de acordo com os termos deste acordo terap\u00eautico.''';

  static const int duracaoPadraoFallback = 60;
  static const int antecedenciaPadraoFallback = 1440;

  static const List<int> opcoesDuracaoMinutos = [30, 45, 50, 60, 90, 120];
  static const List<int> opcoesAntecedenciaMinutos = [
    30, 60, 120, 180, 360, 720, 1440, 2880,
  ];

  Box<String> get _box => Hive.box<String>(_boxName);

  String _encrypt(String value) => encrypt(value);
  String _decrypt(String value) => decrypt(value);

  int get duracaoPadraoSessaoMinutos {
    final valor = int.tryParse(_box.get(_kDuracaoSessaoMin) ?? '');
    return valor ?? duracaoPadraoFallback;
  }

  Future<void> setDuracaoPadraoSessaoMinutos(int minutos) async {
    await _box.put(_kDuracaoSessaoMin, '$minutos');
  }

  bool get lembretePadraoAtivado =>
      _box.get(_kLembretePadraoAtivado) == 'true';

  Future<void> setLembretePadraoAtivado(bool ativado) async {
    await _box.put(_kLembretePadraoAtivado, '$ativado');
  }

  int get antecedenciaPadraoMinutos {
    final valor = int.tryParse(_box.get(_kAntecedenciaPadraoMin) ?? '');
    return valor ?? antecedenciaPadraoFallback;
  }

  Future<void> setAntecedenciaPadraoMinutos(int minutos) async {
    await _box.put(_kAntecedenciaPadraoMin, '$minutos');
  }

  bool get sugerirArtigos => _box.get(_kSugerirArtigos) != 'false';

  Future<void> setSugerirArtigos(bool ativado) async {
    await _box.put(_kSugerirArtigos, '$ativado');
  }

  bool get temaEscuro => _box.get(_kTemaEscuro) == 'true';

  Future<void> setTemaEscuro(bool ativado) async {
    await _box.put(_kTemaEscuro, '$ativado');
  }

  String get canalLembretePadrao =>
      _box.get(_kCanalLembretePadrao) ?? 'whatsapp';

  Future<void> setCanalLembretePadrao(String canal) async {
    await _box.put(_kCanalLembretePadrao, canal);
  }

  String get contratoTemplate {
    final valor = _box.get(_kContratoTemplate);
    if (valor == null || valor.isEmpty) return contratoPadrao;
    return _decrypt(valor);
  }

  Future<void> setContratoTemplate(String texto) async {
    await _box.put(_kContratoTemplate, _encrypt(texto));
  }

  double get valorPadraoSessao {
    final valor = double.tryParse(_box.get(_kValorPadraoSessao) ?? '');
    return valor ?? 0.0;
  }

  Future<void> setValorPadraoSessao(double valor) async {
    await _box.put(_kValorPadraoSessao, '$valor');
  }

  bool get controleFinanceiroAtivo =>
      _box.get(_kControleFinanceiroAtivo) != 'false';

  Future<void> setControleFinanceiroAtivo(bool ativado) async {
    await _box.put(_kControleFinanceiroAtivo, '$ativado');
  }

  bool get demoCriado => _box.get(_kDemoCriado, defaultValue: 'false') == 'true';

  Future<void> setDemoCriado(bool v) => _box.put(_kDemoCriado, '$v');

  bool get biometriaAtivada =>
      _box.get(_kBiometriaAtivada, defaultValue: 'true') == 'true';

  Future<void> setBiometriaAtivada(bool ativado) async {
    await _box.put(_kBiometriaAtivada, '$ativado');
  }

  bool get onboardingConcluido =>
      _box.get(_kOnboardingConcluido, defaultValue: 'false') == 'true';

  Future<void> setOnboardingConcluido(bool v) async =>
      _box.put(_kOnboardingConcluido, '$v');

  /// Frequência do backup automático: 'off' (desativado), 'diario', 'semanal'
  /// ou 'mensal'. Onde a última chave 'off' = nunca automático.
  String get backupFrequencia =>
      _box.get(_kBackupFrequencia, defaultValue: 'off') ?? 'off';

  Future<void> setBackupFrequencia(String v) async {
    await _box.put(_kBackupFrequencia, v);
  }

  /// Diretório escolhido pelo usuário para salvar o backup; vazio = padrão do
  /// app (documentos internos).
  String get backupLocal => _box.get(_kBackupLocal, defaultValue: '') ?? '';

  Future<void> setBackupLocal(String v) async {
    await _box.put(_kBackupLocal, v);
  }

  /// Data/hora do último backup bem-sucedido (ISO 8601), ou null se nunca.
  DateTime? get ultimoBackupEm {
    final valor = _box.get(_kUltimoBackupEm);
    if (valor == null || valor.isEmpty) return null;
    return DateTime.tryParse(valor);
  }

  Future<void> setUltimoBackupEm(DateTime v) async {
    await _box.put(_kUltimoBackupEm, v.toIso8601String());
  }

  Stream<BoxEvent> observar() {
    return _box.watch();
  }

  Future<void> removerCriptografiaExistente() async {
    if (encryption == null || !encryption!.configurado) return;
    final valor = _box.get(_kContratoTemplate);
    if (valor != null && (valor.startsWith('2:') || valor.startsWith('3:'))) {
      await _box.put(_kContratoTemplate, _decrypt(valor));
    }
  }
}
