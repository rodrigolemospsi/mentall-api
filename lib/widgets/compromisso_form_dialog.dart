import 'package:flutter/material.dart';

import '../models/compromisso.dart';
import '../models/paciente.dart';

Future<Compromisso?> mostrarCompromissoFormDialog({
  required BuildContext context,
  required List<Paciente> pacientes,
  String termoPessoa = 'Pessoa atendida',
  DateTime? dataSugerida,
  Compromisso? compromissoExistente,
  int duracaoPadraoMinutos = 60,
  bool lembretePadraoAtivado = false,
  int antecedenciaPadraoMinutos = 1440,
}) async {
  return showDialog<Compromisso>(
    context: context,
    builder: (ctx) => _CompromissoFormDialog(
      pacientes: pacientes,
      termoPessoa: termoPessoa,
      dataSugerida: dataSugerida ?? DateTime.now(),
      compromissoExistente: compromissoExistente,
      duracaoPadraoMinutos: duracaoPadraoMinutos,
      lembretePadraoAtivado: lembretePadraoAtivado,
      antecedenciaPadraoMinutos: antecedenciaPadraoMinutos,
    ),
  );
}

class _CompromissoFormDialog extends StatefulWidget {
  final List<Paciente> pacientes;
  final String termoPessoa;
  final DateTime dataSugerida;
  final Compromisso? compromissoExistente;
  final int duracaoPadraoMinutos;
  final bool lembretePadraoAtivado;
  final int antecedenciaPadraoMinutos;

  const _CompromissoFormDialog({
    required this.pacientes,
    required this.termoPessoa,
    required this.dataSugerida,
    this.compromissoExistente,
    this.duracaoPadraoMinutos = 60,
    this.lembretePadraoAtivado = false,
    this.antecedenciaPadraoMinutos = 1440,
  });

  @override
  State<_CompromissoFormDialog> createState() => _CompromissoFormDialogState();
}

class _CompromissoFormDialogState extends State<_CompromissoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late Paciente _pacienteSelecionado;
  late DateTime _data;
  late TimeOfDay _horaInicio;
  late TimeOfDay _horaFim;
  late TextEditingController _tituloController;
  late TextEditingController _observacoesController;
  late TextEditingController _mensagemLembreteController;
  late bool _lembreteAtivado;
  late int _minutosAntecedencia;

  bool get _editando => widget.compromissoExistente != null;

  @override
  void initState() {
    super.initState();
    final existente = widget.compromissoExistente;

    if (existente != null) {
      _data = DateTime(
        existente.dataHoraInicio.year,
        existente.dataHoraInicio.month,
        existente.dataHoraInicio.day,
      );
      _horaInicio = TimeOfDay.fromDateTime(existente.dataHoraInicio);
      _horaFim = TimeOfDay.fromDateTime(existente.dataHoraFim);
      _tituloController = TextEditingController(text: existente.titulo);
      _observacoesController = TextEditingController(text: existente.observacoes);
      _mensagemLembreteController = TextEditingController(text: existente.mensagemLembrete);
      _lembreteAtivado = existente.lembreteAtivado;
      _minutosAntecedencia = existente.minutosAntecedencia;

      final pacienteEncontrado = widget.pacientes
          .where((p) => p.id == existente.pacienteId)
          .toList();
      _pacienteSelecionado = pacienteEncontrado.isNotEmpty
          ? pacienteEncontrado.first
          : widget.pacientes.first;
    } else {
      _data = DateTime(
        widget.dataSugerida.year,
        widget.dataSugerida.month,
        widget.dataSugerida.day,
      );
      final agora = TimeOfDay.now();
      _horaInicio = TimeOfDay(hour: agora.hour, minute: 0);
      _horaFim = _calcularHoraFim(_horaInicio);
      _tituloController = TextEditingController();
      _observacoesController = TextEditingController();
      _mensagemLembreteController = TextEditingController();
      _lembreteAtivado = widget.lembretePadraoAtivado;
      _minutosAntecedencia = widget.antecedenciaPadraoMinutos;
      _pacienteSelecionado = widget.pacientes.first;
    }
  }

  TimeOfDay _calcularHoraFim(TimeOfDay inicio) {
    final totalMinutos =
        inicio.hour * 60 + inicio.minute + widget.duracaoPadraoMinutos;
    return TimeOfDay(
      hour: (totalMinutos ~/ 60) % 24,
      minute: totalMinutos % 60,
    );
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _observacoesController.dispose();
    _mensagemLembreteController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (escolhida != null) {
      setState(() => _data = escolhida);
    }
  }

  Future<void> _selecionarHoraInicio() async {
    final escolhida = await showTimePicker(
      context: context,
      initialTime: _horaInicio,
    );
    if (escolhida != null) {
      setState(() {
        _horaInicio = escolhida;
        _horaFim = _calcularHoraFim(escolhida);
      });
    }
  }

  Future<void> _selecionarHoraFim() async {
    final escolhida = await showTimePicker(
      context: context,
      initialTime: _horaFim,
    );
    if (escolhida != null) {
      setState(() => _horaFim = escolhida);
    }
  }

  void _salvar() {
    if (!_formKey.currentState!.validate()) return;

    final dataHoraInicio = DateTime(
      _data.year,
      _data.month,
      _data.day,
      _horaInicio.hour,
      _horaInicio.minute,
    );
    final dataHoraFim = DateTime(
      _data.year,
      _data.month,
      _data.day,
      _horaFim.hour,
      _horaFim.minute,
    );

    if (dataHoraFim.isBefore(dataHoraInicio) ||
        dataHoraFim.isAtSameMomentAs(dataHoraInicio)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O horário de término deve ser posterior ao de início.'),
        ),
      );
      return;
    }

    final existente = widget.compromissoExistente;
    final compromisso = Compromisso(
      id: existente?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      pacienteId: _pacienteSelecionado.id,
      dataHoraInicio: dataHoraInicio,
      dataHoraFim: dataHoraFim,
      titulo: _tituloController.text.trim(),
      observacoes: _observacoesController.text.trim(),
      status: existente?.status ?? 'agendado',
      sessaoId: existente?.sessaoId,
      dataCriacao: existente?.dataCriacao,
      lembreteAtivado: _lembreteAtivado,
      minutosAntecedencia: _minutosAntecedencia,
      mensagemLembrete: _mensagemLembreteController.text.trim(),
    );

    Navigator.pop(context, compromisso);
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();
    return '$dia/$mes/$ano';
  }

  String _formatarAntecedencia() {
    if (_minutosAntecedencia < 60) return '$_minutosAntecedencia min';
    final horas = _minutosAntecedencia ~/ 60;
    final mins = _minutosAntecedencia % 60;
    if (mins == 0) return '$horas h';
    return '${horas}h${mins}min';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editando ? 'Editar compromisso' : 'Novo compromisso'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<Paciente>(
                initialValue: _pacienteSelecionado,
                decoration: InputDecoration(
                  labelText: widget.termoPessoa,
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                items: widget.pacientes.map((p) {
                  return DropdownMenuItem(value: p, child: Text(p.nome));
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _pacienteSelecionado = v);
                },
                validator: (v) =>
                    v == null ? 'Selecione uma pessoa' : null,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selecionarData,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(_formatarData(_data)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selecionarHoraInicio,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Início',
                          prefixIcon: Icon(Icons.access_time),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(_horaInicio.format(context)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _selecionarHoraFim,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Término',
                          prefixIcon: Icon(Icons.access_time),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(_horaFim.format(context)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título (opcional)',
                  hintText: 'Ex: Sessão de acompanhamento',
                  prefixIcon: Icon(Icons.label_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _observacoesController,
                decoration: const InputDecoration(
                  labelText: 'Observações (opcional)',
                  hintText: 'Ex: Levar material específico',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Lembrete via SMS',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        _lembreteAtivado
                            ? 'Enviar ${_formatarAntecedencia()} antes da sessao'
                            : 'Notificar o paciente automaticamente',
                      ),
                      value: _lembreteAtivado,
                      onChanged: (v) =>
                          setState(() => _lembreteAtivado = v),
                      activeThumbColor: const Color(0xFF2563EB),
                    ),
                    if (_lembreteAtivado) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _minutosAntecedencia,
                        decoration: const InputDecoration(
                          labelText: 'Antecedencia do lembrete',
                          prefixIcon: Icon(Icons.timer_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 30, child: Text('30 minutos')),
                          DropdownMenuItem(value: 60, child: Text('1 hora')),
                          DropdownMenuItem(value: 120, child: Text('2 horas')),
                          DropdownMenuItem(value: 180, child: Text('3 horas')),
                          DropdownMenuItem(value: 360, child: Text('6 horas')),
                          DropdownMenuItem(value: 720, child: Text('12 horas')),
                          DropdownMenuItem(value: 1440, child: Text('24 horas')),
                          DropdownMenuItem(value: 2880, child: Text('48 horas')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _minutosAntecedencia = v);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _mensagemLembreteController,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Mensagem do lembrete',
                          hintText:
                              'Use {nome}, {data}, {hora} e {profissional} '
                              'como placeholders',
                          prefixIcon: const Icon(Icons.message_outlined),
                          border: const OutlineInputBorder(),
                          alignLabelWithHint: true,
                          helperText: _mensagemLembreteController.text.isEmpty
                              ? 'Ex: Ola {nome}, lembrete da sessao em {data} as {hora}.'
                              : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _salvar,
          child: Text(_editando ? 'Salvar' : 'Criar'),
        ),
      ],
    );
  }
}
