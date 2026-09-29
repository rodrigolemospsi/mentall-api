import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import 'api_client.dart';

/// Telemetria (Fase 2): presença (heartbeat) e uso (eventos), **sem PII**.
///
/// Envia apenas números: `device_id` (UUID aleatório do aparelho), plataforma,
/// versão do app e o **tipo** do evento. Nunca nome de paciente nem conteúdo
/// clínico. É best-effort: falha de rede não quebra o app; os eventos ficam
/// numa fila local e são reenviados quando a conexão volta.
class TelemetriaService {
  static const String _deviceIdKey = 'device_id';
  static const String _filaKey = 'telemetria_fila';
  static const int _filaMax = 200;

  /// Allowlist espelhada no backend (`services/telemetria.py`).
  static const List<String> eventosPermitidos = [
    'sessao_salva',
    'transcricao',
    'sintese',
    'paciente_criado',
    'contrato_enviado',
    'anamnese_enviada',
  ];

  Box<String> get _box => Hive.box<String>('app_config');

  /// Identificador anônimo e estável do aparelho (UUID aleatório persistido).
  String get deviceId {
    final existente = _box.get(_deviceIdKey);
    if (existente != null && existente.isNotEmpty) return existente;
    final novo = const Uuid().v4();
    _box.put(_deviceIdKey, novo);
    return novo;
  }

  String get plataforma {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  Future<String> _versaoApp() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '';
    }
  }

  /// Envia um heartbeat (presença) e tenta esvaziar a fila. Best-effort:
  /// qualquer falha (rede, box ausente, etc.) é ignorada — telemetria nunca
  /// pode quebrar o app.
  Future<void> heartbeat() async {
    try {
      await ApiClient.post(
        '/telemetria/heartbeat',
        body: {
          'device_id': deviceId,
          'plataforma': plataforma,
          'versao_app': await _versaoApp(),
        },
        customTimeout: const Duration(seconds: 15),
      );
      await _flushFila();
    } catch (_) {
      // Best-effort.
    }
  }

  /// Registra um evento de uso. Só tipos da allowlist; best-effort + fila.
  Future<void> registrarEvento(String tipo) async {
    if (!eventosPermitidos.contains(tipo)) return;
    try {
      await _enfileirar(tipo);
      await _flushFila();
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _enfileirar(String tipo) async {
    final fila = _lerFila();
    fila.add(tipo);
    if (fila.length > _filaMax) {
      fila.removeRange(0, fila.length - _filaMax);
    }
    await _salvarFila(fila);
  }

  List<String> _lerFila() {
    final raw = _box.get(_filaKey);
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      final lista = jsonDecode(raw);
      if (lista is List) return lista.map((e) => e.toString()).toList();
    } catch (_) {}
    return <String>[];
  }

  Future<void> _salvarFila(List<String> fila) async {
    if (fila.isEmpty) {
      await _box.delete(_filaKey);
    } else {
      await _box.put(_filaKey, jsonEncode(fila));
    }
  }

  Future<void> _flushFila() async {
    final fila = _lerFila();
    if (fila.isEmpty) return;
    final restante = <String>[];
    for (var i = 0; i < fila.length; i++) {
      final ok = await _enviarEvento(fila[i]);
      if (!ok) {
        restante.addAll(fila.sublist(i));
        break;
      }
    }
    await _salvarFila(restante);
  }

  Future<bool> _enviarEvento(String tipo) async {
    try {
      final res = await ApiClient.post(
        '/telemetria/evento',
        body: {'device_id': deviceId, 'tipo': tipo},
        customTimeout: const Duration(seconds: 15),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
