import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/endereco_consultorio.dart';
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
final _atendeOnlineProvider = StateProvider<bool>((ref) => false);
final _enderecoRebuildProvider = StateProvider<int>((ref) => 0);

class _EnderecoFormData {
  final TextEditingController apelido;
  final TextEditingController cep;
  final TextEditingController logradouro;
  final TextEditingController numero;
  final TextEditingController complemento;
  final TextEditingController bairro;
  final TextEditingController cidade;
  final TextEditingController estado;
  final TextEditingController pais;
  bool cepBuscado;

  _EnderecoFormData({EnderecoConsultorio? endereco})
      : apelido = TextEditingController(text: endereco?.apelido ?? ''),
        cep = TextEditingController(text: endereco?.cep ?? ''),
        logradouro = TextEditingController(text: endereco?.logradouro ?? ''),
        numero = TextEditingController(text: endereco?.numero ?? ''),
        complemento = TextEditingController(text: endereco?.complemento ?? ''),
        bairro = TextEditingController(text: endereco?.bairro ?? ''),
        cidade = TextEditingController(text: endereco?.cidade ?? ''),
        estado = TextEditingController(text: endereco?.estado ?? ''),
        pais = TextEditingController(text: endereco?.pais ?? 'Brasil'),
        cepBuscado = false;

  void dispose() {
    apelido.dispose();
    cep.dispose();
    logradouro.dispose();
    numero.dispose();
    complemento.dispose();
    bairro.dispose();
    cidade.dispose();
    estado.dispose();
    pais.dispose();
  }

  EnderecoConsultorio toEndereco() => EnderecoConsultorio(
        apelido: apelido.text,
        cep: cep.text,
        logradouro: logradouro.text,
        numero: numero.text,
        complemento: complemento.text,
        bairro: bairro.text,
        cidade: cidade.text,
        estado: estado.text,
        pais: pais.text,
      );
}

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
  final List<_EnderecoFormData> _enderecoControllers = [];
  bool _carregandoCep = false;

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
        ref.read(_atendeOnlineProvider.notifier).state = perfil.atendeOnline;
        for (final e in perfil.enderecosConsultorios) {
          _enderecoControllers.add(_EnderecoFormData(endereco: e));
        }
      }
    } catch (erro) {
      Log.erro(erro, contexto: 'perfil_profissional_form_page:initState');
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _registroController.dispose();
    for (final e in _enderecoControllers) {
      e.dispose();
    }
    super.dispose();
  }

  void _triggerEnderecoRebuild() {
    ref.read(_enderecoRebuildProvider.notifier).state++;
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

  Future<void> _buscarCep(int index) async {
    if (_carregandoCep) return;
    final cepCtrl = _enderecoControllers[index].cep;
    final cepDigitos = cepCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (cepDigitos.length != 8) return;

    setState(() => _carregandoCep = true);
    try {
      final response = await http
          .get(Uri.parse('https://viacep.com.br/ws/$cepDigitos/json/'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data.containsKey('erro') && data['erro'] == true) return;

      final form = _enderecoControllers[index];
      form.logradouro.text = data['logradouro'] as String? ?? '';
      form.bairro.text = data['bairro'] as String? ?? '';
      form.cidade.text = data['localidade'] as String? ?? '';
      form.estado.text = data['uf'] as String? ?? '';
      form.cepBuscado = true;
      _triggerEnderecoRebuild();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _carregandoCep = false);
    }
  }

  void _adicionarEndereco() {
    _enderecoControllers.add(_EnderecoFormData());
    _triggerEnderecoRebuild();
  }

  void _removerEndereco(int index) {
    _enderecoControllers[index].dispose();
    _enderecoControllers.removeAt(index);
    _triggerEnderecoRebuild();
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
            content: Text(
                'Aceite os Termos de Uso e Política de Privacidade para continuar.'),
          ),
        );
        ref.read(_salvandoProvider.notifier).state = false;
        return;
      }

      final enderecos =
          _enderecoControllers.map((e) => e.toEndereco()).toList();
      final modalidades = <String>[];
      if (ref.read(_atendeOnlineProvider)) {
        modalidades.add('Online');
      }
      if (enderecos.isNotEmpty) {
        modalidades.add('Presencial');
      }

      final perfil = PerfilProfissional(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nome: nome,
        registroProfissional: registro,
        abordagemClinica: ref.read(_abordagemProvider),
        termoPessoaAtendida: ref.read(_termoProvider),
        fotoBase64: ref.read(_fotoProvider),
        modalidadesAtendimentoJson: jsonEncode(modalidades),
        enderecosConsultoriosJson: jsonEncode(
          enderecos.map((e) => e.toJson()).toList(),
        ),
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
    ref.watch(_enderecoRebuildProvider);

    final abordagensOrdenadas = PerfilProfissional.abordagensDisponiveis
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: corPrincipal,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _cardCabecalho(corPrincipal, fotoBase64, salvando, abordagemSelecionada,
                termoSelecionado, abordagensOrdenadas),
            const SizedBox(height: 16),
            _cardInfo(corPrincipal),
            const SizedBox(height: 16),
            _secaoEnderecos(corPrincipal),
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

  Widget _cardCabecalho(
    Color corPrincipal,
    String fotoBase64,
    bool salvando,
    String abordagemSelecionada,
    String termoSelecionado,
    List<dynamic> abordagensOrdenadas,
  ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Image.asset(
                'assets/images/logo_mentall.png',
                height: 80,
              ),
            ),
            const SizedBox(height: 10),
            const Text('Bem-vindo ao MentAll',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Antes de cadastrar pessoas atendidas, configure seu perfil profissional e suas preferências clínicas.',
              style: TextStyle(color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 22),
            Center(
              child: GestureDetector(
                onTap: salvando ? null : _selecionarFoto,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: corPrincipal.withValues(alpha: 0.1),
                      backgroundImage: fotoBase64.isNotEmpty
                          ? MemoryImage(base64Decode(fotoBase64))
                          : null,
                      child: fotoBase64.isEmpty
                          ? Icon(Icons.camera_alt_outlined,
                              size: 32, color: corPrincipal)
                          : null,
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: corPrincipal,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
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
                  .map((a) => DropdownMenuItem<String>(
                        value: a.value,
                        child: Text(a.value),
                      ))
                  .toList(),
              onChanged: salvando
                  ? null
                  : (value) {
                      if (value == null) return;
                      ref.read(_abordagemProvider.notifier).state = value;
                    },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: termoSelecionado,
              decoration: const InputDecoration(
                labelText: 'Como prefere se referir à pessoa atendida?',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.record_voice_over_outlined),
              ),
              items: PerfilProfissional.termosPessoaAtendidaDisponiveis
                  .map((t) => DropdownMenuItem<String>(
                        value: t.value,
                        child: Text(_capitalizarTermo(t.value)),
                      ))
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
    );
  }

  Widget _cardInfo(Color corPrincipal) {
    return Card(
      elevation: 0,
      color: corPrincipal.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: corPrincipal.withValues(alpha: 0.12)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Color(0xFF2563EB)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Essas preferências serão usadas para adaptar a linguagem do app e orientar os apontamentos da IA conforme sua abordagem clínica.',
                style: TextStyle(color: Colors.black87, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secaoEnderecos(Color corPrincipal) {
    final atendeOnline = ref.watch(_atendeOnlineProvider);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 20, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Endereço(s) de atendimento',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B)),
                  ),
                ),
                TextButton.icon(
                  onPressed: _adicionarEndereco,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_enderecoControllers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Nenhum endereço cadastrado. Toque em "Adicionar" para cadastrar um local de atendimento.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
              )
            else
              ..._enderecoControllers.asMap().entries.map((entry) {
                final index = entry.key;
                return _cardEndereco(index, corPrincipal);
              }),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: atendeOnline,
                  activeColor: corPrincipal,
                  onChanged: (value) {
                    ref.read(_atendeOnlineProvider.notifier).state =
                        value ?? false;
                  },
                ),
                const Expanded(
                  child: Text(
                    'Realizo atendimento online',
                    style: TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardEndereco(int index, Color corPrincipal) {
    final form = _enderecoControllers[index];
    final podeRemover = _enderecoControllers.length > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: corPrincipal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Endereço ${index + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
              const Spacer(),
              if (podeRemover)
                IconButton(
                  onPressed: () => _removerEndereco(index),
                  icon: const Icon(Icons.close, size: 18),
                  color: const Color(0xFFD32F2F),
                  splashRadius: 16,
                  tooltip: 'Remover endereço',
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: form.apelido,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nome / Apelido',
              hintText: 'Ex.: Consultório Centro',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: form.cep,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'CEP',
              hintText: 'Ex.: 01310100',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: _carregandoCep
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search, size: 20),
                      onPressed: () => _buscarCep(index),
                      tooltip: 'Buscar endereço pelo CEP',
                    ),
            ),
            onSubmitted: (_) => _buscarCep(index),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: form.logradouro,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Rua / Av.',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: form.numero,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Número',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: TextField(
                  controller: form.complemento,
                  decoration: const InputDecoration(
                    labelText: 'Complemento',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: form.bairro,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Bairro',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: form.cidade,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Cidade',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: form.estado,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Estado / Província',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: form.pais,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'País',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
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
                    'Eu li e aceito os Termos de Uso e a Política de Privacidade.',
                    style: TextStyle(height: 1.4),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 4,
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
                  child: const Text('Política de Privacidade'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _capitalizarTermo(String termo) {
    final termoLimpo = termo.trim();
    if (termoLimpo.isEmpty) return termoLimpo;
    return termoLimpo[0].toUpperCase() + termoLimpo.substring(1);
  }
}
