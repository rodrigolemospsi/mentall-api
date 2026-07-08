import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_providers.dart';
import '../models/paciente.dart';
import '../services/api_client.dart';
import '../services/logger.dart';
import '../widgets/estado_vazio_pacientes.dart';
import '../widgets/novo_paciente_dialog.dart';
import '../widgets/paciente_card_home.dart';
import 'backup_restore_page.dart';
import 'lgpd/privacidade_seguranca_page.dart';
import 'paciente_detail_page.dart';
import 'perfil_profissional_form_page.dart';

final _buscaTermoProvider = StateProvider<String>((ref) => '');

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  List<Paciente> _filtrarPacientes(
      List<Paciente> pacientes, String termoBusca) {
    if (termoBusca.isEmpty) return pacientes;
    return pacientes.where((p) {
      return p.nome.trim().toLowerCase().contains(termoBusca);
    }).toList();
  }

  String get _termoSingular {
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    return perfil?.termoSingular ?? 'paciente';
  }

  String get _termoSingularCapitalizado {
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    return perfil?.termoSingularCapitalizado ?? 'Paciente';
  }

  String get _termoPlural {
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    return perfil?.termoPlural ?? 'pacientes';
  }

  bool get _termoFeminino {
    return _termoSingular == 'pessoa atendida';
  }

  String get _novoOuNova {
    return _termoFeminino ? 'Nova' : 'Novo';
  }

  String get _nenhumOuNenhuma {
    return _termoFeminino ? 'Nenhuma' : 'Nenhum';
  }

  String get _primeiroOuPrimeira {
    return _termoFeminino ? 'primeira' : 'primeiro';
  }

  String get _cadastradoOuCadastrada {
    return _termoFeminino ? 'cadastrada' : 'cadastrado';
  }

  String get _arquivadoOuArquivada {
    return _termoFeminino ? 'arquivada' : 'arquivado';
  }

  String get _saudacao {
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    if (perfil == null) return 'MentAll';
    return 'Olá, ${perfil.nomeExibicao}';
  }

  String get _restauradoOuRestaurada {
    return _termoFeminino ? 'restaurada' : 'restaurado';
  }

  String get _doOuDa {
    return _termoFeminino ? 'da' : 'do';
  }

  String get _buscarHint {
    return ref.read(perfilProfissionalServiceProvider)
            .obterPerfil()?.buscarPessoaHint ?? 'Buscar';
  }

  Widget _indicadorPendencias() {
    final pendentes = ref.read(sessaoServiceProvider)
        .contarSessoesPendentesRevisao();
    if (pendentes == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        color: const Color(0xFFFFF3E0),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.rate_review_outlined, color: Color(0xFFE65100)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$pendentes sess${pendentes == 1 ? 'ão' : 'ões'} pendente${pendentes == 1 ? '' : 's'} de revisão',
                  style: const TextStyle(
                    color: Color(0xFFE65100),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _abrirPerfil() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PerfilProfissionalFormPage(),
      ),
    );
  }

  Future<void> _abrirConfigServidor() async {
    final controller = TextEditingController(text: ApiClient.baseUrlExibicao);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Servidor backend'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'URL do servidor',
                hintText: 'http://192.168.1.24:8000',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns_outlined),
              ),
              keyboardType: TextInputType.url,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Informe a URL';
                final uri = Uri.tryParse(v.trim());
                if (uri == null || !uri.hasScheme) return 'URL invalida';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                await ApiClient.setBaseUrl(controller.text.trim());
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('URL do servidor atualizada.')),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  Future<void> _abrirDialogNovoPaciente() async {
    final pacienteService = ref.read(pacienteServiceProvider);
    await mostrarDialogNovoPaciente(
      context: context,
      pacienteService: pacienteService,
      termoSingular: _termoSingular,
      termoSingularCapitalizado: _termoSingularCapitalizado,
      novoOuNova: _novoOuNova,
      cadastradoOuCadastrada: _cadastradoOuCadastrada,
      doOuDa: _doOuDa,
    );
  }

  Future<void> _confirmarArquivamentoPaciente(Paciente paciente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Arquivar $_termoSingular'),
          content: Text(
            'Deseja arquivar $_termoSingular ${paciente.nome}?\n\n'
            'O cadastro deixará de aparecer na lista ativa, mas continuará preservado e poderá ser restaurado posteriormente.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Arquivar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      await ref.read(pacienteServiceProvider).arquivarPaciente(paciente);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$_termoSingularCapitalizado $_arquivadoOuArquivada com sucesso.',
          ),
        ),
      );
    } catch (erro) {
      Log.erro(erro, contexto: 'home_page:arquivarPaciente');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível arquivar $_doOuDa $_termoSingular. Tente novamente.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmarRestauracaoPaciente(Paciente paciente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Restaurar $_termoSingular'),
          content: Text(
            'Deseja restaurar $_termoSingular ${paciente.nome}?\n\n'
            'O cadastro voltará a aparecer na lista ativa.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.restore_outlined),
              label: const Text('Restaurar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      await ref.read(pacienteServiceProvider).restaurarPaciente(paciente);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$_termoSingularCapitalizado $_restauradoOuRestaurada com sucesso.',
          ),
        ),
      );
    } catch (erro) {
      Log.erro(erro, contexto: 'home_page:restaurarPaciente');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível restaurar $_doOuDa $_termoSingular. Tente novamente.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color corPrincipal = Color(0xFF1F6F78);

    final pacientesAtivosAsync = ref.watch(pacientesAtivosProvider);
    final pacientesArquivadosAsync = ref.watch(pacientesArquivadosProvider);
    final termoBusca = ref.watch(_buscaTermoProvider);

    final pacientesAtivos = _filtrarPacientes(
      pacientesAtivosAsync.valueOrNull ?? [],
      termoBusca,
    );
    final pacientesArquivados = _filtrarPacientes(
      pacientesArquivadosAsync.valueOrNull ?? [],
      termoBusca,
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FA),
        appBar: AppBar(
          title: Text(_saudacao),
          centerTitle: false,
          backgroundColor: corPrincipal,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'Perfil profissional',
              onPressed: _abrirPerfil,
            ),
            IconButton(
              icon: const Icon(Icons.backup_outlined),
              tooltip: 'Backup e restauração',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BackupRestorePage(),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.shield_outlined),
              tooltip: 'Privacidade e Seguranca',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrivacidadeSegurancaPage(),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.dns_outlined),
              tooltip: 'Configurar servidor',
              onPressed: _abrirConfigServidor,
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.75),
            indicatorColor: Colors.white,
            tabs: const [
              Tab(
                icon: Icon(Icons.people_alt_outlined),
                text: 'Ativos',
              ),
              Tab(
                icon: Icon(Icons.archive_outlined),
                text: 'Arquivados',
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                onChanged: (value) =>
                    ref.read(_buscaTermoProvider.notifier).state =
                        value.trim().toLowerCase(),
                decoration: InputDecoration(
                  hintText: _buscarHint,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            _indicadorPendencias(),
            Expanded(
              child: TabBarView(
                children: [
                  _ListaPacientes(
                    pacientes: pacientesAtivos,
                    termoSingular: _termoSingular,
                    termoPlural: _termoPlural,
                    nenhumOuNenhuma: _nenhumOuNenhuma,
                    primeiroOuPrimeira: _primeiroOuPrimeira,
                    cadastradoOuCadastrada: _cadastradoOuCadastrada,
                    listaArquivada: false,
                    onAbrirPaciente: (paciente) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PacienteDetailPage(
                            paciente: paciente,
                          ),
                        ),
                      );
                    },
                    onArquivarPaciente: _confirmarArquivamentoPaciente,
                    onRestaurarPaciente: _confirmarRestauracaoPaciente,
                  ),
                  _ListaPacientes(
                    pacientes: pacientesArquivados,
                    termoSingular: _termoSingular,
                    termoPlural: _termoPlural,
                    nenhumOuNenhuma: _nenhumOuNenhuma,
                    primeiroOuPrimeira: _primeiroOuPrimeira,
                    cadastradoOuCadastrada: _cadastradoOuCadastrada,
                    listaArquivada: true,
                    onAbrirPaciente: (paciente) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PacienteDetailPage(
                            paciente: paciente,
                          ),
                        ),
                      );
                    },
                    onArquivarPaciente: _confirmarArquivamentoPaciente,
                    onRestaurarPaciente: _confirmarRestauracaoPaciente,
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _abrirDialogNovoPaciente,
          backgroundColor: corPrincipal,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: Text('$_novoOuNova $_termoSingular'),
        ),
      ),
    );
  }
}

class _ListaPacientes extends StatelessWidget {
  final List<Paciente> pacientes;
  final String termoSingular;
  final String termoPlural;
  final String nenhumOuNenhuma;
  final String primeiroOuPrimeira;
  final String cadastradoOuCadastrada;
  final bool listaArquivada;
  final void Function(Paciente paciente) onAbrirPaciente;
  final void Function(Paciente paciente) onArquivarPaciente;
  final void Function(Paciente paciente) onRestaurarPaciente;

  const _ListaPacientes({
    required this.pacientes,
    required this.termoSingular,
    required this.termoPlural,
    required this.nenhumOuNenhuma,
    required this.primeiroOuPrimeira,
    required this.cadastradoOuCadastrada,
    required this.listaArquivada,
    required this.onAbrirPaciente,
    required this.onArquivarPaciente,
    required this.onRestaurarPaciente,
  });

  @override
  Widget build(BuildContext context) {
    if (pacientes.isEmpty) {
      return EstadoVazioPacientes(
        termoSingular: termoSingular,
        termoPlural: termoPlural,
        nenhumOuNenhuma: nenhumOuNenhuma,
        primeiroOuPrimeira: primeiroOuPrimeira,
        cadastradoOuCadastrada: cadastradoOuCadastrada,
        listaArquivada: listaArquivada,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pacientes.length,
      itemBuilder: (context, index) {
        final paciente = pacientes[index];
        return PacienteCardHome(
          paciente: paciente,
          termoSingular: termoSingular,
          listaArquivada: listaArquivada,
          onTap: () {
            onAbrirPaciente(paciente);
          },
          onArquivar: () {
            onArquivarPaciente(paciente);
          },
          onRestaurar: () {
            onRestaurarPaciente(paciente);
          },
        );
      },
    );
  }
}
