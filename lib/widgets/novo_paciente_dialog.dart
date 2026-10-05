import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/paciente.dart';
import '../services/logger.dart';
import '../services/paciente_service.dart';
import '../services/telemetria_service.dart';
import '../services/lgpd/auditoria_service.dart';
import '../utils/imagem_cache.dart';
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
  TelemetriaService? telemetriaService,
}) async {
  final nomeController = TextEditingController();
  final contatoController = TextEditingController();
  final emailController = TextEditingController();
  final dataNascimentoController = TextEditingController();
  final observacoesController = TextEditingController();
  String? fotoBase64;

  String tipoAtendimento = 'Particular';
  String? modoAtendimento;
  String tratamento = 'masculino';
  bool salvando = false;
  String? erroDataNascimento;

  String estadoAtual() => jsonEncode({
        'nome': nomeController.text,
        'contato': contatoController.text,
        'email': emailController.text,
        'nascimento': dataNascimentoController.text,
        'observacoes': observacoesController.text,
        'foto': fotoBase64,
        'tipo': tipoAtendimento,
        'modo': modoAtendimento,
        'tratamento': tratamento,
      });
  final snapshotInicial = estadoAtual();

  Future<void> confirmarDescarte(BuildContext dialogContext) async {
    if (salvando) return;
    if (estadoAtual() == snapshotInicial) {
      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
      return;
    }
    final descartar = await showDialog<bool>(
      context: dialogContext,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content:
            const Text('Há alterações não salvas. Seus dados serão perdidos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (descartar == true && dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }
  }

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) return;
                confirmarDescarte(dialogContext);
              },
              child: AlertDialog(
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
                              ? fotoMemoria(fotoBase64!)
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
                      maxLength: 120,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nome completo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contatoController,
                      maxLength: 20,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Contato',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      maxLength: 120,
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
                      decoration: InputDecoration(
                        labelText: 'Data de nascimento',
                        hintText: 'dd/mm/aaaa',
                        errorText: erroDataNascimento,
                        border: const OutlineInputBorder(),
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
                          final txt = '${digits.substring(0, 2)}/${digits.substring(2, 4)}/${digits.substring(4, digits.length.clamp(4, 8))}';
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
                    DropdownButtonFormField<String>(
                      initialValue: tratamento,
                      decoration: const InputDecoration(
                        labelText: 'Tratamento',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'masculino',
                          child: Text('Masculino'),
                        ),
                        DropdownMenuItem(
                          value: 'feminino',
                          child: Text('Feminino'),
                        ),
                      ],
                      onChanged: salvando
                          ? null
                          : (value) {
                              if (value == null) return;
                              setDialogState(() {
                                tratamento = value;
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
                      : () => confirmarDescarte(dialogContext),
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
                          DateTime? dataNascimento;
                          final dataTexto = dataNascimentoController.text.trim();
                          String? erroData;
                          if (dataTexto.isNotEmpty) {
                            final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(dataTexto);
                            if (match == null) {
                              erroData = 'Use o formato dd/mm/aaaa.';
                            } else {
                              final dia = int.parse(match.group(1)!);
                              final mes = int.parse(match.group(2)!);
                              final ano = int.parse(match.group(3)!);
                              dataNascimento = DateTime(ano, mes, dia);
                              if (ano < 1 || dataNascimento.year != ano ||
                                  dataNascimento.month != mes || dataNascimento.day != dia) {
                                erroData = 'Informe uma data de nascimento válida.';
                              } else if (dataNascimento.isAfter(DateTime.now())) {
                                erroData = 'A data de nascimento não pode ser futura.';
                              }
                            }
                          }
                          setDialogState(() {
                            erroDataNascimento = erroData;
                          });
                          if (erroData != null) return;
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
                              modoAtendimento: modoAtendimento ?? '',
                              observacoes: observacoesController.text.trim(),
                              fotoBase64: fotoBase64 ?? '',
                              tratamento: tratamento,
                            );
                            await pacienteService.adicionarPaciente(paciente);
                            await auditoriaService?.registrar(
                              tipoEvento:
                                  '$termoSingularCapitalizado $cadastradoOuCadastrada',
                              descricao: nome,
                              pacienteId: paciente.id,
                            );
                            telemetriaService?.registrarEvento('paciente_criado');
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
                          } finally {
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
              ),
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
