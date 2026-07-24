import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/paciente.dart';
import '../services/logger.dart';
import '../services/paciente_service.dart';
import '../services/lgpd/auditoria_service.dart';
import '../utils/mentall_colors.dart';

Future<void> mostrarDialogNovoPaciente({
  required BuildContext context,
  required PacienteService pacienteService,
  required String termoSingular,
  required String termoSingularCapitalizado,
  required String novoOuNova,
  required String cadastradoOuCadastrada,
  required String doOuDa,
  List<String> opcoesModoAtendimento = const [],
  AuditoriaService? auditoriaService,
}) async {
  final nomeController = TextEditingController();
  final contatoController = TextEditingController();
  final emailController = TextEditingController();
  final dataNascimentoController = TextEditingController();
  final observacoesController = TextEditingController();
  String? fotoBase64;

  String tipoAtendimento = 'Particular';
  String? modoAtendimento;
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
                    Center(
                      child: GestureDetector(
                        onTap: salvando
                            ? null
                            : () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 512,
                                  maxHeight: 512,
                                  imageQuality: 85,
                                );
                                if (picked != null) {
                                  final bytes =
                                      await picked.readAsBytes();
                                  setDialogState(() {
                                    fotoBase64 = base64Encode(bytes);
                                  });
                                }
                              },
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: context.corSuperficie,
                          backgroundImage: fotoBase64 != null
                              ? MemoryImage(base64Decode(fotoBase64!))
                              : null,
                          child: fotoBase64 == null
                              ? Icon(Icons.camera_alt_outlined,
                                  size: 28, color: context.corTextoMuted)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                    TextField(
                      controller: dataNascimentoController,
                      keyboardType: TextInputType.datetime,
                      decoration: const InputDecoration(
                        labelText: 'Data de nascimento',
                        hintText: 'dd/mm/aaaa',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final digits = value.replaceAll(RegExp(r'[^\d]'), '');
                        if (digits.length > 2 && digits.length <= 4) {
                          final txt = '${digits.substring(0, 2)}/${digits.substring(2)}';
                          if (txt != value) {
                            dataNascimentoController.value = TextEditingValue(
                              text: txt,
                              selection: TextSelection.collapsed(offset: txt.length),
                            );
                          }
                        } else if (digits.length > 4) {
                          final txt = '${digits.substring(0, 2)}/${digits.substring(2, 4)}/${digits.substring(4, 8)}';
                          if (txt != value) {
                            dataNascimentoController.value = TextEditingValue(
                              text: txt,
                              selection: TextSelection.collapsed(offset: txt.length),
                            );
                          }
                        }
                      },
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
                    if (opcoesModoAtendimento.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: modoAtendimento,
                        decoration: const InputDecoration(
                          labelText: 'Modalidade de atendimento',
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text('Selecione a modalidade'),
                        items: opcoesModoAtendimento.map((modo) {
                          return DropdownMenuItem(
                            value: modo,
                            child: Row(
                              children: [
                                Icon(
                                  modo == 'Online'
                                      ? Icons.videocam_outlined
                                      : Icons.location_on_outlined,
                                  size: 16,
                                  color: context.corTextoMuted,
                                ),
                                const SizedBox(width: 8),
                                Text(modo),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: salvando
                            ? null
                            : (value) {
                                setDialogState(() {
                                  modoAtendimento = value;
                                });
                              },
                      ),
                    ],
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
                            DateTime? dataNascimento;
                            final dataTexto = dataNascimentoController.text.trim();
                            if (dataTexto.isNotEmpty) {
                              final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(dataTexto);
                              if (match == null) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Data de nascimento deve estar no formato dd/mm/aaaa.'),
                                  ),
                                );
                                return;
                              }
                              dataNascimento = DateTime(
                                int.parse(match.group(3)!),
                                int.parse(match.group(2)!),
                                int.parse(match.group(1)!),
                              );
                            }
                            final paciente = Paciente(
                              id: DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString(),
                              nome: nome,
                              contato: contatoController.text.trim(),
                              email: emailController.text.trim(),
                              dataNascimento: dataNascimento,
                              tipoAtendimento: tipoAtendimento,
                              modoAtendimento: modoAtendimento ?? '',
                              observacoes: observacoesController.text.trim(),
                              fotoBase64: fotoBase64 ?? '',
                            );
                            await pacienteService.adicionarPaciente(paciente);
                            await auditoriaService?.registrar(
                              tipoEvento:
                                  '$termoSingularCapitalizado $cadastradoOuCadastrada',
                              descricao: nome,
                              pacienteId: paciente.id,
                            );
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
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.corOnPrimaria,
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
    dataNascimentoController.dispose();
    observacoesController.dispose();
  }
}
