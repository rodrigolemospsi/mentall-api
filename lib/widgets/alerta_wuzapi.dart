import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/whatsapp_conexao_page.dart';
import '../services/wuzapi_service.dart';

/// Alerta na Home quando o WhatsApp (Wuzapi) está desconectado ou sem conexão.
///
/// Verifica ao abrir a Home, quando o app volta do segundo plano e a cada 60 s.
/// Se a consulta falhar (ex.: sem internet), mantém o estado anterior para não
/// gerar falso alarme.
class AlertaWuzapi extends StatefulWidget {
  const AlertaWuzapi({
    super.key,
    this.obterStatus,
    this.monitorar = true,
  });

  /// Permite injetar a consulta de status em testes.
  final Future<Map<String, dynamic>> Function()? obterStatus;

  /// Liga/desliga o polling periódico (desligado nos testes de widget).
  final bool monitorar;

  @override
  State<AlertaWuzapi> createState() => _AlertaWuzapiState();
}

class _AlertaWuzapiState extends State<AlertaWuzapi>
    with WidgetsBindingObserver {
  static const Duration _intervalo = Duration(seconds: 60);

  Timer? _timer;
  bool _jaConsultou = false;
  bool _desconectado = false;
  bool _naoConfigurado = false;

  Future<Map<String, dynamic>> _status() =>
      (widget.obterStatus ?? WuzapiService.status)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verificar();
    if (widget.monitorar) {
      _timer = Timer.periodic(_intervalo, (_) => _verificar());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verificar();
    }
  }

  Future<void> _verificar() async {
    Map<String, dynamic> resultado;
    try {
      resultado = await _status();
    } catch (_) {
      return; // sem conexão com o servidor: mantém estado anterior
    }
    if (!mounted) return;
    if (resultado['sucesso'] != true) return; // erro: não gera falso alarme

    final configurado = resultado['configurado'] == true;
    final conectado = resultado['conectado'] == true;
    final logado = resultado['logado'] == true;

    setState(() {
      _jaConsultou = true;
      _naoConfigurado = !configurado;
      _desconectado = configurado && (!conectado || !logado);
    });
  }

  Future<void> _abrirConexao() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WhatsappConexaoPage()),
    );
    if (mounted) _verificar();
  }

  @override
  Widget build(BuildContext context) {
    if (!_jaConsultou) return const SizedBox.shrink();
    if (!_naoConfigurado && !_desconectado) return const SizedBox.shrink();

    final titulo =
        _naoConfigurado ? 'WhatsApp não conectado' : 'WhatsApp desconectado';
    final detalhe = _naoConfigurado
        ? 'Conecte o WhatsApp para que os lembretes das sessões sejam enviados.'
        : 'A conexão caiu. Reconecte para não perder os lembretes das sessões.';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0B429)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Color(0xFFB45309)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7C2D12),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detalhe,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF7C2D12)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _abrirConexao,
            child: const Text('Reconectar'),
          ),
        ],
      ),
    );
  }
}
