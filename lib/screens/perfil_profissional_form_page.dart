import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/perfil_profissional.dart';
import '../providers/service_providers.dart';
import '../services/logger.dart';
import 'home_page.dart';
import 'lgpd/politica_privacidade_page.dart';
import 'lgpd/termos_uso_page.dart';

final _abordagemProvider = StateProvider<String>((ref) => 'Integrativa');
final _termoProvider = StateProvider<String>((ref) => 'paciente');
final _salvandoProvider = StateProvider<bool>((ref) => false);
final _aceitouTermosProvider = StateProvider<bool>((ref) => false);
final _fotoProvider = StateProvider<String>((ref) => '');

class PerfilProfissionalFormPage extends ConsumerStatefulWidget {
  const PerfilProfissionalFormPage({super.key});

  @override
  ConsumerState<PerfilProfissionalFormPage> createState() =>
      _PerfilProfissionalFormPageState();
}

class _PerfilProfissionalFormPageState
    extends ConsumerState<PerfilProfissionalFormPage> {
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _registroController = TextEditingController();

  @override
  void initState() {
    super.initState();
    try {
      final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
      if (perfil != null) {
        _nomeController.text = perfil.nome;
        _registroController.text = perfil.registroProfissional;
        ref.read(_abordagemProvider.notifier).state = perfil.abordagemClinica;
        ref.read(_termoProvider.notifier).state = perfil.termoPessoaAtendida;
        ref.read(_fotoProvider.notifier).state = perfil.fotoBase64;
      }
    } catch (erro) {
      Log.erro(erro, contexto: 'perfil_profissional_form_page:initState');
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _registroController.dispose();
    super.dispose();
  }

  Future<void> _selecionarFoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    ref.read(_fotoProvider.notifier).state = base64Encode(bytes);
  }

  Future<void> _salvarPerfil() async {
    if (ref.read(_salvandoProvider)) return;

    final nome = _nomeController.text.trim();
    final registro = _registroController.text.trim();

    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe seu nome profissional.'),
        ),
      );
      return;
    }

    ref.read(_salvandoProvider.notifier).state = true;

    try {
      if (!ref.read(_aceitouTermosProvider)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aceite os Termos de Uso e Politica de Privacidade para continuar.'),
          ),
        );
        ref.read(_salvandoProvider.notifier).state = false;
        return;
      }

      final perfil = PerfilProfissional(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nome: nome,
        registroProfissional: registro,
        abordagemClinica: ref.read(_abordagemProvider),
        termoPessoaAtendida: ref.read(_termoProvider),
        fotoBase64: ref.read(_fotoProvider),
      );

      await ref.read(perfilProfissionalServiceProvider).salvarPerfil(perfil);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomePage(),
        ),
      );
    } catch (erro) {
      Log.erro(erro, contexto: 'perfil_profissional_form_page:salvar');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível salvar o perfil profissional. Tente novamente.',
          ),
        ),
      );
    } finally {
      if (mounted) ref.read(_salvandoProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color corPrincipal = Color(0xFF2563EB);
    final abordagemSelecionada = ref.watch(_abordagemProvider);
    final termoSelecionado = ref.watch(_termoProvider);
    final salvando = ref.watch(_salvandoProvider);
    final fotoBase64 = ref.watch(_fotoProvider);

    final abordagensOrdenadas = PerfilProfissional.abordagensDisponiveis
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Configuração inicial'),
        backgroundColor: corPrincipal,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.psychology_alt_outlined,
                      size: 44,
                      color: corPrincipal,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Bem-vindo ao MentAll',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Antes de cadastrar pessoas atendidas, configure seu perfil profissional e suas preferências clínicas.',
                      style: TextStyle(
                        color: const Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Center(
                      child: GestureDetector(
                        onTap: salvando ? null : _selecionarFoto,
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: corPrincipal.withValues(alpha: 0.1),
                          backgroundImage: fotoBase64.isNotEmpty
                              ? MemoryImage(base64Decode(fotoBase64))
                              : null,
                          child: fotoBase64.isEmpty
                              ? const Icon(Icons.camera_alt_outlined,
                                  size: 32, color: corPrincipal)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: salvando ? null : _selecionarFoto,
                        icon: const Icon(Icons.add_a_photo, size: 16),
                        label: Text(
                          fotoBase64.isNotEmpty ? 'Alterar foto' : 'Adicionar foto',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _nomeController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nome profissional',
                        hintText: 'Ex.: Rodrigo Silva',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _registroController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Registro profissional',
                        hintText: 'Ex.: CRP 00/00000',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: abordagemSelecionada,
                      decoration: const InputDecoration(
                        labelText: 'Abordagem clínica principal',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_tree_outlined),
                      ),
                      items: abordagensOrdenadas
                          .map(
                            (a) => DropdownMenuItem<String>(
                              value: a.value,
                              child: Text(a.value),
                            ),
                          )
                          .toList(),
                      onChanged: salvando
                          ? null
                          : (value) {
                              if (value == null) return;
                              ref.read(_abordagemProvider.notifier).state =
                                  value;
                            },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: termoSelecionado,
                      decoration: const InputDecoration(
                        labelText:
                            'Como prefere se referir à pessoa atendida?',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.record_voice_over_outlined),
                      ),
                      items: PerfilProfissional
                          .termosPessoaAtendidaDisponiveis
                          .map(
                            (t) => DropdownMenuItem<String>(
                              value: t.value,
                              child: Text(_capitalizarTermo(t.value)),
                            ),
                          )
                          .toList(),
                      onChanged: salvando
                          ? null
                          : (value) {
                              if (value == null) return;
                              ref.read(_termoProvider.notifier).state = value;
                            },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: corPrincipal.withValues(alpha: 0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: corPrincipal.withValues(alpha: 0.12),
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: corPrincipal,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Essas preferências serão usadas para adaptar a linguagem do app e, futuramente, orientar os apontamentos da IA conforme sua abordagem clínica.',
                        style: TextStyle(
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _secaoConsentimento(corPrincipal),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: salvando ? null : _salvarPerfil,
              icon: salvando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                salvando ? 'Salvando...' : 'Salvar e começar',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: corPrincipal,
                foregroundColor: Colors.white,
                disabledBackgroundColor: corPrincipal.withValues(alpha: 0.6),
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalizarTermo(String termo) {
    final termoLimpo = termo.trim();
    if (termoLimpo.isEmpty) {
      return termoLimpo;
    }
    return termoLimpo[0].toUpperCase() + termoLimpo.substring(1);
  }

  Widget _secaoConsentimento(Color corPrincipal) {
    final aceitou = ref.watch(_aceitouTermosProvider);

    return Card(
      elevation: 0,
      color: const Color(0xFFEFF6FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFDBEAFE)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: aceitou,
                  activeColor: corPrincipal,
                  onChanged: (value) {
                    ref.read(_aceitouTermosProvider.notifier).state =
                        value ?? false;
                  },
                ),
                const Expanded(
                  child: Text(
                    'Eu li e aceito os Termos de Uso e a Politica de Privacidade.',
                    style: TextStyle(height: 1.4),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TermosUsoPage()),
                    );
                  },
                  child: const Text('Termos de Uso'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PoliticaPrivacidadePage()),
                    );
                  },
                  child: const Text('Politica de Privacidade'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
