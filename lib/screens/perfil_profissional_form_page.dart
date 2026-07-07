import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/perfil_profissional.dart';
import '../providers/service_providers.dart';
import '../services/logger.dart';
import 'home_page.dart';

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

  String _abordagemSelecionada = 'Integrativa';
  String _termoSelecionado = 'paciente';

  bool _salvando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _registroController.dispose();
    super.dispose();
  }

  Future<void> _salvarPerfil() async {
    if (_salvando) return;

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

    setState(() {
      _salvando = true;
    });

    try {
      final perfil = PerfilProfissional(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nome: nome,
        registroProfissional: registro,
        abordagemClinica: _abordagemSelecionada,
        termoPessoaAtendida: _termoSelecionado,
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
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color corPrincipal = Color(0xFF1F6F78);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA),
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
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
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
                      initialValue: _abordagemSelecionada,
                      decoration: const InputDecoration(
                        labelText: 'Abordagem clínica principal',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_tree_outlined),
                      ),
                      items: PerfilProfissional.abordagensDisponiveis
                          .map(
                            (a) => DropdownMenuItem<String>(
                              value: a.value,
                              child: Text(a.value),
                            ),
                          )
                          .toList(),
                      onChanged: _salvando
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                _abordagemSelecionada = value;
                              });
                            },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _termoSelecionado,
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
                      onChanged: _salvando
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                _termoSelecionado = value;
                              });
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
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _salvando ? null : _salvarPerfil,
              icon: _salvando
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
                _salvando ? 'Salvando...' : 'Salvar e começar',
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
}
