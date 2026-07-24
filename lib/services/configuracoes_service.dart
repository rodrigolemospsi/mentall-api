import 'package:hive_ce/hive.dart';

class ConfiguracoesService {
  static const String _boxName = 'app_config';

  static const String _kDuracaoSessaoMin = 'duracao_padrao_sessao_min';
  static const String _kLembretePadraoAtivado = 'lembrete_padrao_ativado';
  static const String _kAntecedenciaPadraoMin =
      'lembrete_antecedencia_padrao_min';
  static const String _kSugerirArtigos = 'ia_sugerir_artigos';
  static const String _kTemaEscuro = 'tema_escuro';
  static const String _kCanalLembretePadrao = 'canal_lembrete_padrao';

  static const int duracaoPadraoFallback = 60;
  static const int antecedenciaPadraoFallback = 1440;

  static const List<int> opcoesDuracaoMinutos = [30, 45, 50, 60, 90, 120];
  static const List<int> opcoesAntecedenciaMinutos = [
    30, 60, 120, 180, 360, 720, 1440, 2880,
  ];

  Box<String> get _box => Hive.box<String>(_boxName);

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

  Stream<BoxEvent> observar() {
    return _box.watch();
  }
}
