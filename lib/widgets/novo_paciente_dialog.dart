import 'package:flutter/material.dart';

import '../models/paciente.dart';
import '../services/logger.dart';
import '../services/paciente_service.dart';

Future<void> mostrarDialogNovoPaciente({
  required BuildContext context,
  required PacienteService pacienteService,
  required String termoSingular,
  required String termoSingularCapitalizado,
  required String novoOuNova,
  required String cadastradoOuCadastrada,
  required String doOuDa,
}) async {
  final nomeController = TextEditingController();
  final contatoController = TextEditingController();
  final emailController = TextEditingController();
  final observacoesController = TextEditingController();
  DateTime? dataNascimento;

  String tipoAtendimento = 'Particular';
  bool salvando = false;

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text('$novoOuNova $termoSingular'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomeController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nome completo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contatoController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Contato',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: salvando
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: dialogContext,
                                initialDate:
                                    dataNascimento ?? DateTime.now(),
                                firstDate: DateTime(1900),
                                lastDate: DateTime.now(),
                                helpText: 'Data de nascimento',
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  dataNascimento = picked;
                                });
                              }
                            },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Data de nascimento',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          dataNascimento != null
                              ? '${dataNascimento!.day.toString().padLeft(2, '0')}/${dataNascimento!.month.toString().padLeft(2, '0')}/${dataNascimento!.year}'
                              : 'Informe a data de nascimento',
                          style: TextStyle(
                            color: dataNascimento != null
                                ? null
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: tipoAtendimento,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de atendimento',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Particular',
                          child: Text('Particular'),
                        ),
                        DropdownMenuItem(
                          value: 'Convênio',
                          child: Text('Convênio'),
                        ),
                        DropdownMenuItem(
                          value: 'Outro',
                          child: Text('Outro'),
                        ),
                      ],
                      onChanged: salvando
                          ? null
                          : (value) {
                              if (value == null) return;
                              setDialogState(() {
                                tipoAtendimento = value;
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: observacoesController,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Observações',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: salvando
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: salvando
                      ? null
                      : () async {
                          final nome = nomeController.text.trim();
                          if (nome.isEmpty) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Informe o nome $doOuDa $termoSingular.',
                                ),
                              ),
                            );
                            return;
                          }
                          setDialogState(() {
                            salvando = true;
                          });
                          try {
                            final paciente = Paciente(
                              id: DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString(),
                              nome: nome,
                              contato: contatoController.text.trim(),
                              email: emailController.text.trim(),
                              dataNascimento: dataNascimento,
                              tipoAtendimento: tipoAtendimento,
                              observacoes: observacoesController.text.trim(),
                            );
                            await pacienteService.adicionarPaciente(paciente);
                            if (!context.mounted) return;
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '$termoSingularCapitalizado $cadastradoOuCadastrada com sucesso.',
                                ),
                              ),
                            );
                          } catch (erro) {
                            Log.erro(erro, contexto: 'home_page:cadastrarPaciente');
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Não foi possível cadastrar $doOuDa $termoSingular. Tente novamente.',
                                ),
                              ),
                            );
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                salvando = false;
                              });
                            }
                          }
                        },
                  child: salvando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    nomeController.dispose();
    contatoController.dispose();
    emailController.dispose();
    observacoesController.dispose();
  }
}
