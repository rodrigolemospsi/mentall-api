import 'package:flutter/material.dart';

import '../models/compromisso.dart';
import '../models/enums.dart';
import '../models/paciente.dart';
import '../services/compromisso_service.dart';

Future<Compromisso?> mostrarCompromissoFormDialog({
  required BuildContext context,
  required List<Paciente> pacientes,
  String termoPessoa = 'Pessoa atendida',
  DateTime? dataSugerida,
  Compromisso? compromissoExistente,
  int duracaoPadraoMinutos = 60,
  bool lembretePadraoAtivado = false,
  int antecedenciaPadraoMinutos = 1440,
  required CompromissoService compromissoService,
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
      compromissoService: compromissoService,
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
  final CompromissoService compromissoService;

  const _CompromissoFormDialog({
    required this.pacientes,
    required this.termoPessoa,
    required this.dataSugerida,
    this.compromissoExistente,
    this.duracaoPadraoMinutos = 60,
    this.lembretePadraoAtivado = false,
    this.antecedenciaPadraoMinutos = 1440,
    required this.compromissoService,
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
  late String _canalLembrete;
  late FrequenciaRecorrencia _recorrencia;
  late DateTime? _dataLimiteRecorrencia;

  bool get _editando => widget.compromissoExistente != null;
  bool get _editandoRecorrente =>
      _editando && widget.compromissoExistente!.ehFilhoDeRecorrencia;

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
      _canalLembrete = existente.canalLembrete.isNotEmpty ? existente.canalLembrete : 'whatsapp';
      _recorrencia = FrequenciaRecorrencia.nenhuma;
      _dataLimiteRecorrencia = null;

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
      _canalLembrete = 'whatsapp';
      _recorrencia = FrequenciaRecorrencia.nenhuma;
      _dataLimiteRecorrencia = null;
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

    final conflitos = widget.compromissoService.verificarConflitos(
      dataHoraInicio,
      dataHoraFim,
      ignorarId: widget.compromissoExistente?.id,
    );

    if (conflitos.isNotEmpty) {
      final nomes = conflitos.map((c) => c.titulo.isEmpty ? 'Compromisso' : c.titulo).join(', ');
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Conflito de horário'),
          content: Text('Já existe(m) compromisso(s) neste horário: $nomes.\n\nDeseja agendar mesmo assim?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _confirmarSalvar(dataHoraInicio, dataHoraFim);
              },
              child: const Text('Agendar assim mesmo'),
            ),
          ],
        ),
      );
      return;
    }

    _confirmarSalvar(dataHoraInicio, dataHoraFim);
  }

  void _confirmarSalvar(DateTime dataHoraInicio, DateTime dataHoraFim) {
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
      canalLembrete: _canalLembrete,
      recorrencia: _recorrencia.value,
      dataLimiteRecorrencia: _dataLimiteRecorrencia,
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
              const SizedBox(height: 16),
              if (!_editando) ...[
                DropdownButtonFormField<FrequenciaRecorrencia>(
                  initialValue: _recorrencia,
                  decoration: const InputDecoration(
                    labelText: 'Repetir',
                    prefixIcon: Icon(Icons.repeat),
                    border: OutlineInputBorder(),
                  ),
                  items: FrequenciaRecorrencia.values.map((f) {
                    return DropdownMenuItem(
                      value: f,
                      child: Text(f.value.isEmpty ? 'Não repete' : f.value),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _recorrencia = v);
                  },
                ),
                if (_recorrencia.temRecorrencia) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final limite = await showDatePicker(
                        context: context,
                        initialDate: _dataLimiteRecorrencia ??
                            _data.add(const Duration(days: 90)),
                        firstDate: _data.add(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                        helpText: 'Data limite da recorrência',
                      );
                      if (limite != null) {
                        setState(() => _dataLimiteRecorrencia = limite);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Até (opcional)',
                        prefixIcon: Icon(Icons.event_repeat),
                        border: OutlineInputBorder(),
                        hintText: 'Padrão: 6 meses',
                      ),
                      child: Text(
                        _dataLimiteRecorrencia != null
                            ? _formatarData(_dataLimiteRecorrencia!)
                            : 'Sem data limite',
                      ),
                    ),
                  ),
                ],
              ],
              if (_editandoRecorrente)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                'Este é um compromisso recorrente.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
                ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Row(
                        children: [
                          Text(
                            _canalLembrete == 'whatsapp'
                                ? 'Lembrete via WhatsApp'
                                : 'Lembrete via SMS',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        _lembreteAtivado
                            ? 'Enviar ${_formatarAntecedencia()} antes da sessão'
                            : 'Notificar o paciente automaticamente',
                      ),
                      value: _lembreteAtivado,
                      onChanged: (v) =>
                          setState(() => _lembreteAtivado = v),
                      activeThumbColor: Theme.of(context).colorScheme.primary,
                    ),
                    if (_lembreteAtivado) ...[
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(
                            value: 'whatsapp',
                            label: Text('WhatsApp'),
                            icon: Icon(Icons.chat_outlined, size: 18),
                          ),
                          ButtonSegment<String>(
                            value: 'sms',
                            label: Text('SMS'),
                            icon: Icon(Icons.sms_outlined, size: 18),
                          ),
                        ],
                        selected: {_canalLembrete},
                        onSelectionChanged: (sel) {
                          setState(() => _canalLembrete = sel.first);
                        },
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _minutosAntecedencia,
                        decoration: const InputDecoration(
                          labelText: 'Antecedência do lembrete',
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
                              ? 'Ex: Olá {nome}, lembrete da sessão em {data} às {hora}.'
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
