import 'package:flutter/material.dart';

import '../models/compromisso.dart';
import '../models/paciente.dart';

Future<Compromisso?> mostrarCompromissoFormDialog({
  required BuildContext context,
  required List<Paciente> pacientes,
  DateTime? dataSugerida,
  Compromisso? compromissoExistente,
}) async {
  return showDialog<Compromisso>(
    context: context,
    builder: (ctx) => _CompromissoFormDialog(
      pacientes: pacientes,
      dataSugerida: dataSugerida ?? DateTime.now(),
      compromissoExistente: compromissoExistente,
    ),
  );
}

class _CompromissoFormDialog extends StatefulWidget {
  final List<Paciente> pacientes;
  final DateTime dataSugerida;
  final Compromisso? compromissoExistente;

  const _CompromissoFormDialog({
    required this.pacientes,
    required this.dataSugerida,
    this.compromissoExistente,
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
      _horaFim = TimeOfDay(hour: agora.hour + 1, minute: 0);
      _tituloController = TextEditingController();
      _observacoesController = TextEditingController();
      _pacienteSelecionado = widget.pacientes.first;
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _observacoesController.dispose();
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
        _horaFim = TimeOfDay(
          hour: escolhida.hour,
          minute: escolhida.minute,
        ).replacing(hour: escolhida.hour + 1);
      });
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
    );

    Navigator.pop(context, compromisso);
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();
    return '$dia/$mes/$ano';
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
                decoration: const InputDecoration(
                  labelText: 'Pessoa atendida',
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
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Término',
                        prefixIcon: Icon(Icons.access_time),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_horaFim.format(context)),
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
