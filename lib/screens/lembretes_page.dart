import 'package:flutter/material.dart';

import '../services/lembrete_service.dart';
import '../utils/mentall_colors.dart';
import '../utils/raio.dart';
import '../utils/tipografia.dart';

class LembretesPage extends StatefulWidget {
  const LembretesPage({super.key});

  @override
  State<LembretesPage> createState() => _LembretesPageState();
}

class _LembretesPageState extends State<LembretesPage> {
  static const _verde = Color(0xFF2E7D32);
  static const _azul = Color(0xFF1976D2);

  bool _carregando = true;
  bool _cancelando = false;
  List<Map<String, dynamic>> _lembretes = const [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final lista = await LembreteService.listarLembretes();
    if (!mounted) return;
    setState(() {
      _lembretes = lista;
      _carregando = false;
    });
  }

  Future<void> _cancelarTodos() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar todos os lembretes?'),
        content: const Text(
          'Os lembretes pendentes não serão mais enviados por WhatsApp. '
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancelar todos'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _cancelando = true);
    final total = await LembreteService.cancelarTodosLembretes();
    if (!mounted) return;
    setState(() => _cancelando = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          total > 0
              ? '$total lembrete(s) cancelado(s).'
              : 'Nenhum lembrete pendente para cancelar.',
        ),
      ),
    );
    await _carregar();
  }

  String _formatarDataHora(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      final dia = d.day.toString().padLeft(2, '0');
      final mes = d.month.toString().padLeft(2, '0');
      final hora = d.hour.toString().padLeft(2, '0');
      final min = d.minute.toString().padLeft(2, '0');
      return '$dia/$mes/${d.year} às $hora:$min';
    } catch (_) {
      return iso;
    }
  }

  (Color, String) _statusInfo(String status) {
    switch (status) {
      case 'enviado':
        return (_verde, 'Enviado');
      case 'falha':
        return (context.corError, 'Falhou');
      case 'cancelado':
        return (context.corTextoSecondary, 'Cancelado');
      case 'pendente':
      default:
        return (_azul, 'Pendente');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendentes =
        _lembretes.where((l) => (l['status'] ?? 'pendente') == 'pendente').length;

    return Scaffold(
      backgroundColor: context.corFundo,
      appBar: AppBar(
        title: const Text('Lembretes agendados'),
        actions: [
          if (_carregando || _cancelando)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: pendentes > 0 ? _cancelarTodos : null,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancelar todos'),
            ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregar,
              child: _lembretes.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                        Center(
                          child: Text(
                            'Nenhum lembrete agendado.',
                            style: TextStyle(
                              fontSize: Tipografia.base,
                              color: context.corTextoSecondary,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _lembretes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _card(context, _lembretes[i]),
                    ),
            ),
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> lembrete) {
    final status = (lembrete['status'] ?? 'pendente').toString();
    final (cor, label) = _statusInfo(status);
    final mensagem = (lembrete['mensagem'] ?? '').toString();
    final telefone = (lembrete['telefone'] ?? '').toString();
    final horario = (lembrete['horario_envio'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.corCard,
        borderRadius: BorderRadius.circular(Raio.md),
        border: context.corCardBorda,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mensagem.isEmpty ? 'Lembrete de sessão' : mensagem,
                  style: TextStyle(
                    fontSize: Tipografia.base,
                    fontWeight: FontWeight.w600,
                    color: context.corTextoBody,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Raio.xs),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: Tipografia.xs,
                    fontWeight: FontWeight.w600,
                    color: cor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.schedule_outlined, size: 15, color: context.corTextoSecondary),
              const SizedBox(width: 4),
              Text(
                _formatarDataHora(horario),
                style: TextStyle(
                  fontSize: Tipografia.smMd,
                  color: context.corTextoSecondary,
                ),
              ),
            ],
          ),
          if (telefone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 15, color: context.corTextoSecondary),
                const SizedBox(width: 4),
                Text(
                  telefone,
                  style: TextStyle(
                    fontSize: Tipografia.smMd,
                    color: context.corTextoSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
