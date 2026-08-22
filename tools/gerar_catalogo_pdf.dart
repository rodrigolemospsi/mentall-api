import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() async {
  final pdf = pw.Document(
    title: 'Catálogo de Funcionalidades - MentAll PRO',
    author: 'MentAll PRO',
  );

  const primaria = PdfColor.fromInt(0xFF2066FF);
  const cinza = PdfColor.fromInt(0xFF64748B);
  const heading = PdfColor.fromInt(0xFF1E293B);
  const body = PdfColor.fromInt(0xFF334155);
  const bg = PdfColor.fromInt(0xFFF8FAFC);
  const linha = PdfColor.fromInt(0xFFE2E8F0);

  pw.TextStyle tituloSecao(int nivel) => pw.TextStyle(
    fontSize: nivel == 1 ? 18 : nivel == 2 ? 14 : 12,
    fontWeight: nivel <= 2 ? pw.FontWeight.bold : pw.FontWeight.normal,
    color: nivel == 1 ? primaria : nivel == 2 ? heading : body,
  );

  pw.Widget espaco([double h = 6]) => pw.SizedBox(height: h);

  pw.Widget cabecalho() => pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 4),
    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: linha, width: 0.5))),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('MentAll PRO', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: primaria)),
        pw.Text('Catálogo de Funcionalidades', style: const pw.TextStyle(fontSize: 10, color: cinza)),
      ],
    ),
  );

  pdf.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    header: (_) => cabecalho(),
    footer: (ctx) => pw.Center(child: pw.Text('Página ${ctx.pageNumber}', style: const pw.TextStyle(fontSize: 7, color: cinza))),
    build: (ctx) => [
      pw.Center(child: pw.Text('MentAll PRO', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: primaria, letterSpacing: 1.5))),
      espaco(4),
      pw.Center(child: pw.Text('Prontuário Clínico com Inteligência Artificial', style: const pw.TextStyle(fontSize: 12, color: cinza))),
      espaco(16),
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(color: bg, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
        child: pw.Text(
          'Aplicativo Flutter para prontuário clínico adaptado à abordagem terapêutica do profissional '
          '(TCC, Psicanálise, ACT, DBT e mais 10 abordagens), com assistência de IA para transcrição e '
          'análise de sessões. Dados criptografados com AES-256-GCM, armazenamento local via Hive CE, '
          'backend Python FastAPI com deploy no Render.',
          style: const pw.TextStyle(fontSize: 10, color: body, height: 1.5),
          textAlign: pw.TextAlign.justify,
        ),
      ),
      espaco(16),

      // ============================================================
      // 1. TELAS
      // ============================================================
      pw.Text('1. Telas (16)', style: tituloSecao(1)),
      espaco(10),

      _tela(pdf, 'AppStartPage', 'Splash screen + roteamento inicial', [
        'Splash screen adaptativo (1s se configurado, 3s se novo) com tap-to-dismiss',
        'Roteamento: Login → Onboarding → Perfil → MainShell',
        'Timeout de inatividade (5 min) — bloqueio automático',
        'Autenticação biométrica no startup',
      ]),
      _tela(pdf, 'LoginPage', 'PIN de 4 dígitos com teclado numérico', [
        'Desbloqueio, configuração e troca de PIN',
        'Recuperação por email (código 6 dígitos)',
        'Lockout exponencial (5 tentativas, máx 1h)',
      ]),
      _tela(pdf, 'OnboardingPage', 'Carrossel introdutório (3 slides)', [
        'Prontuário inteligente, Sua abordagem, Segurança e privacidade',
        'Dots animados + botão Pular/Começar',
      ]),
      _tela(pdf, 'MainShell', 'BottomNavigationBar com 3 abas', [
        'Início (dashboard), Pacientes (lista), Financeiro',
        'IndexedStack — preserva estado entre abas',
      ]),
      _tela(pdf, 'HomePage', 'Dashboard principal', [
        'Saudação por horário (Dr./Dra.) + ações rápidas (Agendar, Novo paciente, Nova sessão)',
        '4 KPIs: Sessões hoje, Pacientes ativos, Receita mês, Pendente financeiro',
        'Feed de atividade recente (últimos 5 registros de auditoria)',
        'Menu ⋮: Perfil, Configurações, Backup, Privacidade, Financeiro',
      ]),
      _tela(pdf, 'AgendaPage', 'Calendário completo (Dia/Semana/Mês)', [
        '3 modos de visualização com navegação por período e botão Hoje',
        'Criação/edição de compromissos com recorrência (semanal/quinzenal/mensal)',
        'Status: Agendado, Realizado, Cancelado, Faltou',
        'Lembretes via notificação local + backend (WhatsApp/SMS)',
      ]),
      _tela(pdf, 'PacientesPage', 'Lista de pacientes com busca', [
        'Abas Ativos/Arquivados com contadores',
        'Busca por nome, email e contato',
        'Cards com avatar, nome, modalidade e revisões pendentes',
      ]),
      _tela(pdf, 'PacienteDetailPage', 'Ficha do paciente (3 abas)', [
        'Resumo: foto, contato, contrato, anamnese, pacotes, evolução',
        'Sessões: histórico completo com arquivar/restaurar + botão Nova sessão',
        'Financeiro: indicadores (Recebido, A receber, Convênio, Pacote, Total)',
        'AppBar: Exportar PDF (5 tipos), Editar, Escalas, Acordo Terapêutico',
      ]),
      _tela(pdf, 'SessaoFormPage', 'Formulário de sessão (2350 linhas)', [
        'Gravação de áudio (5 min máx, AAC 96kbps) com wakelock e criptografia',
        'Transcrição via Groq Whisper (~2 segundos)',
        'Síntese clínica via GPT-4o-mini adaptada à abordagem do profissional',
        'Artigos científicos sugeridos (OpenAlex + rerank IA)',
        'Campos clínicos: Relato, Síntese, Formulação, Intervenções, Apontamentos',
        'Evolução clínica automática (progress tracking)',
        'Seção financeira: valor, status, método, data de pagamento',
        'Edição bloqueada por padrão — toque para editar',
      ]),
      _tela(pdf, 'FinanceiroPage', 'Financeiro mensal', [
        'Seletor de mês/ano com KPIs (Recebido, A receber, Convênio, Pacote, Total)',
        'Lista de sessões com chips de status coloridos',
        'Exportar PDF financeiro com loading indicator',
      ]),
      _tela(pdf, 'PerfilProfissionalFormPage', 'Perfil do profissional', [
        'Foto, nome, CRP (com verificação automática via API do CFP)',
        'Abordagem clínica principal (14 opções)',
        'Termo para pessoa atendida (paciente/cliente/pessoa atendida)',
        'Tratamento (Dr./Dra.) — flexão de gênero em todo o app',
        'Endereços de atendimento com busca de CEP (ViaCEP)',
        'Atendimento online + Termos de Uso/Privacidade',
      ]),
      _tela(pdf, 'ConfiguracoesPage', 'Configurações centralizadas', [
        'Tema escuro (dark mode)',
        'Segurança: ativar/remover PIN, trocar PIN, bloquear agora',
        'Agenda: duração padrão, lembrete padrão, antecedência',
        'IA: toggle de artigos científicos',
        'Servidor: URL customizável com restaurar padrão',
        'Contrato: editor de template do Acordo Terapêutico',
      ]),
      _tela(pdf, 'BackupRestorePage', 'Exportar/Importar backup JSON', [
        'Export: PIN obrigatório (se configurado), descriptografa dados',
        'Import: sobrescreve IDs existentes, re-criptografa ao salvar',
        'Mobile: share_plus + file_picker; Web: Blob download + FileUpload',
      ]),
      _tela(pdf, 'PrivacidadeSegurancaPage', 'Privacidade e Segurança (LGPD)', [
        'Seções: Segurança, Áudio, IA & Privacidade, Dados & Retenção, Auditoria',
        'Registro de eventos (log de auditoria) com tradução para linguagem leiga',
        'Exportar PDF da arquitetura LGPD',
      ]),
      _tela(pdf, 'PoliticaPrivacidadePage + TermosUsoPage', 'Documentos legais', [
        'Política de Privacidade (10 seções) e Termos de Uso (9 seções)',
        'Texto estático formatado, acessível via Privacidade ou Perfil',
      ]),

      // ============================================================
      // 2. SERVIÇOS
      // ============================================================
      pw.NewPage(),
      pw.Text('2. Serviços (27)', style: tituloSecao(1)),
      espaco(10),

      _servico('ApiClient', 'Cliente HTTP centralizado — JWT, credenciais, base URL dinâmica'),
      _servico('EncryptionService', 'AES-256-GCM/CBC + PBKDF2-HMAC-SHA256 (100k iterações)'),
      _servico('AuthService', 'PIN, JWT backend, biometria, inactivity lock, remoção de criptografia'),
      _servico('PacienteService', 'CRUD de pacientes com criptografia (5 campos) e cascade delete (8 boxes)'),
      _servico('PerfilProfissionalService', 'Perfil singleton (nome, CRP, foto) com criptografia'),
      _servico('SessaoService', 'CRUD de sessões (19 campos criptografados), arquivamento, cache de número'),
      _servico('CompromissoService', 'Compromissos com recorrência, conflitos, status e lembretes'),
      _servico('LembreteService', 'Notificações locais + backend (WhatsApp/SMS via Twilio)'),
      _servico('BackupService', 'Export/import JSON completo (13 boxes) com criptografia'),
      _servico('TranscricaoRelatoService', 'Upload de áudio → Groq Whisper (transcrição ~2 segundos)'),
      _servico('IaClinicaService', 'Síntese clínica + progress tracking via GPT-4o-mini/DeepSeek/Gemini'),
      _servico('AudioRelatoService', 'Gravação cross-platform (Web WAV, Mobile AAC .m4a), wakelock, criptografia'),
      _servico('StatusClinicoSessaoService', 'Determina estado clínico da sessão (7 estados possíveis)'),
      _servico('HiveMigrationService', 'Migração de schema Hive (V1→V2→V3)'),
      _servico('PdfExportService', 'Geração de 6 tipos de PDF com marca profissional e dark mode'),
      _servico('ContratoService', 'Acordos terapêuticos — criar, enviar, verificar aceite, arquivar'),
      _servico('ConfiguracoesService', 'Preferências: tema, duração, lembretes, IA, financeiro, contrato template'),
      _servico('AvaliacaoInicialService', 'Anamnese — 6 campos clínicos criptografados'),
      _servico('EscalaService', '3 escalas psicológicas gratuitas (PHQ-9, GAD-7, DASS-21) com scoring automático'),
      _servico('AnamneseEnviadaService', 'Questionários remotos enviados a pacientes via backend'),
      _servico('ProgressoService', 'Evolução clínica automática (sintomas, metas, avaliação, tendência)'),
      _servico('PacoteService', 'Pacotes de sessões — criar, consumir FIFO, consultar saldo'),
      _servico('CrpService', 'Verificação de CRP via API do CFP (proxy backend)'),
      _servico('Logger', 'Logs técnicos com rotação (500 linhas / 1MB) em Hive + arquivo'),
      _servico('EncryptedServiceMixin', 'Mixin reutilizável de criptografia (aplicado em 11 serviços)'),
      _servico('AuditoriaService', 'Registro LGPD com descrições criptografadas, trim a 1000 registros'),
      _servico('PdfArquiteturaLgpdService', 'PDF com 14 seções descrevendo a arquitetura de compliance LGPD'),

      // ============================================================
      // 3. WIDGETS
      // ============================================================
      pw.NewPage(),
      pw.Text('3. Widgets (30+)', style: tituloSecao(1)),
      espaco(10),

      _widget('SaudacaoResumoHome', 'Cabeçalho com saudação + contagem de sessões do dia'),
      _widget('AcoesRapidasHome', '3 botões de ação rápida (Novo Paciente, Agendar, Nova Sessão)'),
      _widget('KpiCardsHome', 'Grade 2×2 de indicadores (Hoje, Pacientes, Receita, Pendente)'),
      _widget('SessoesHojeCard', 'Lista de compromissos do dia com avatar, nome, horário, status'),
      _widget('AtividadeRecenteCard', 'Feed dos últimos 5 registros de auditoria com tempo relativo'),
      _widget('AgendaInlineWidget', 'Calendário inline Dia/Semana/Mês com mini-cards de compromisso'),
      _widget('CompromissoFormDialog', 'Diálogo de criação/edição de compromisso com recorrência e lembretes'),
      _widget('NovoPacienteDialog', 'Diálogo de cadastro com foto, CEP, e validação de email'),
      _widget('PacienteCardHome', 'Card de paciente com avatar, nome, modalidade, WhatsApp, pendências'),
      _widget('PacienteResumoCard', 'Card de resumo na ficha do paciente com info lines e contrato'),
      _widget('SessaoCard', 'Card de sessão com data, status (ícone + chip), arquivar/restaurar'),
      _widget('BotaoAudioCircular', 'Botão circular estilo gravador (gravar, pausar, transcrever, etc.)'),
      _widget('BotoesAudioWidget', 'Barra completa de controles de áudio + botão IA'),
      _widget('TimerGravacaoWidget', 'Timer ao vivo da gravação (MM:SS)'),
      _widget('ProcessamentoIaWidget', 'Indicador de processamento IA com spinner'),
      _widget('ArtigosSugeridosCard', 'Card de artigos científicos com links clicáveis'),
      _widget('SecaoCamposClinicosWidget', '4 seções clínicas (Síntese, Formulação, Intervenções, Apontamentos)'),
      _widget('PacienteResumoTab', 'Aba Resumo — card + anamnese + pacotes + contrato + evolução'),
      _widget('PacienteSessoesTab', 'Aba Sessões — lista ativas/arquivadas + botão Nova sessão'),
      _widget('PacienteFinanceiroTab', 'Aba Financeiro — KPIs + lista de sessões do paciente'),
      _widget('AnamneseCard', 'Card de Avaliação Inicial com preenchimento/edição e auto-população'),
      _widget('EscalasSection', 'Lista de 5 escalas psicológicas com aplicação e resultado'),
      _widget('EstadoVazioPacientes', 'Estado vazio com ícone e mensagem contextual + busca sem resultado'),
      _widget('CampoTextoWidget', 'Wrapper reutilizável de TextField com label'),
      _widget('ListaSessoesAtivas/Arquivadas', 'ListViews de sessões com SessaoCard + estado vazio'),
      _widget('StatusPacienteChip', 'Chip Ativo/Arquivado para cards de paciente'),
      _widget('SessaoInfoChip', 'Chip colorido de status de processamento da sessão (8 estados)'),
      _widget('StatusProcessamentoCard', 'Banner detalhado de status de processamento'),
      _widget('SecaoFormulario', 'Wrapper de card para seções de formulário com título opcional'),
      _widget('InfoLinha', 'Linha de informação (ícone + label + valor) para cards de resumo'),
      _widget('SemSessoesCard', 'Card de estado vazio para listas de sessão'),
      _widget('AvisoPrivacidadeIaCard', 'Banner informativo sobre uso de IA como apoio documental'),

      // ============================================================
      // 4. BACKEND
      // ============================================================
      pw.NewPage(),
      pw.Text('4. Backend (21 endpoints)', style: tituloSecao(1)),
      espaco(10),

      _endpoint('GET', '/health', 'Status do servidor e info do banco (Turso/SQLite)', false),
      _endpoint('POST', '/auth/login', 'Autenticação JWT (bcrypt, 8h expiração)', false),
      _endpoint('POST', '/auth/solicitar-recuperacao', 'Solicitar código de recuperação de PIN (email)', false),
      _endpoint('POST', '/auth/verificar-recuperacao', 'Verificar código de recuperação', false),
      _endpoint('POST', '/auth/registrar-recuperacao', 'Registrar token de recuperação', true),
      _endpoint('POST', '/verificar-crp', 'Verificar CRP via API do CFP', true),
      _endpoint('POST', '/transcrever', 'Transcrever áudio via Groq Whisper (35MB max)', true),
      _endpoint('POST', '/gerar-sintese', 'Síntese clínica via GPT-4o-mini/DeepSeek/Gemini', true),
      _endpoint('POST', '/gerar-progresso', 'Análise de evolução clínica entre sessões', true),
      _endpoint('POST', '/enviar-sms', 'Enviar SMS via Twilio', true),
      _endpoint('POST', '/enviar-whatsapp', 'Enviar WhatsApp via Twilio', true),
      _endpoint('POST', '/contratos', 'Criar acordo terapêutico (token único, template customizável)', true),
      _endpoint('GET', '/contratos/{token}', 'Página HTML do acordo (patient-facing)', false),
      _endpoint('POST', '/contratos/{token}/aceitar', 'Paciente aceita o acordo (patient-facing)', false),
      _endpoint('GET', '/contratos/{token}/status', 'Verificar status do acordo', true),
      _endpoint('POST', '/lembretes', 'Agendar lembrete WhatsApp/SMS', true),
      _endpoint('DELETE', '/lembretes/{compromisso_id}', 'Cancelar lembrete', true),
      _endpoint('POST', '/anamneses', 'Criar questionário de anamnese', true),
      _endpoint('GET', '/anamneses/{token}', 'Página HTML da anamnese (patient-facing)', false),
      _endpoint('POST', '/anamneses/{token}/responder', 'Paciente responde anamnese (patient-facing)', false),
      _endpoint('GET', '/anamneses/{token}/status', 'Verificar status da anamnese', true),

      espaco(10),
      pw.Text('Segurança do Backend', style: tituloSecao(2)),
      espaco(6),
      pw.Bullet(text: 'Rate limiting por IP em 17 endpoints (3 a 30 req/min)'),
      pw.Bullet(text: 'JWT HS256, 480 min expiração, claims: sub, exp, owner (RLS)'),
      pw.Bullet(text: 'Security headers: CSP, HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy'),
      pw.Bullet(text: 'CORS restrito a 8 origins (produção + localhost)'),
      pw.Bullet(text: 'Senha backend: bcrypt com hash configurável via APP_PASSWORD_HASH'),
      pw.Bullet(text: 'Sanitização de prompt injection na IA (_sanitizar_prompt)'),
      pw.Bullet(text: 'Deploy: Render.com (Python 3.12, plano gratuito)'),

      // ============================================================
      // 5. ABORDAGENS CLÍNICAS
      // ============================================================
      pw.NewPage(),
      pw.Text('5. Abordagens Clínicas (14)', style: tituloSecao(1)),
      espaco(10),
      pw.Text('Cada abordagem customiza 14 labels de campos clínicos (pensamentos, emoções, comportamentos, intervenções, técnicas, tarefas, evolução, plano, etc.) que aparecem no formulário de sessão, nos PDFs e nos prompts de IA.', style: const pw.TextStyle(fontSize: 10, color: body)),
      espaco(10),

      for (final a in [
        ('TCC', 'Modelo cognitivo'),
        ('Análise do Comportamento', 'Análise funcional'),
        ('Psicanálise', 'Dinâmica inconsciente'),
        ('Psicodinâmica', 'Processo psicodinâmico'),
        ('Humanista', 'Experiência subjetiva'),
        ('Fenomenológico-existencial', 'Compreensão fenomenológico-existencial'),
        ('Logoterapia', 'Compreensão clínica e sentido'),
        ('Gestalt-terapia', 'Processo gestáltico'),
        ('Sistêmica', 'Formulação sistêmica'),
        ('ACT', 'Flexibilidade psicológica'),
        ('DBT', 'Regulação emocional e habilidades'),
        ('Terapia do Esquema', 'Esquemas, modos e necessidades emocionais'),
        ('Integrativa', 'Formulação clínica (genérica)'),
        ('Outra', 'Formulação clínica (genérica)'),
      ])
        pw.Bullet(text: '${a.$1} — ${a.$2}'),

      // ============================================================
      // 6. ESCALAS PSICOLÓGICAS
      // ============================================================
      espaco(16),
      pw.Text('6. Escalas Psicológicas (3)', style: tituloSecao(1)),
      espaco(10),

      _escala('PHQ-9', 'Questionário de Saúde do Paciente', '9', '0-27', 'Depressão (5 faixas: mínima a grave)'),
      _escala('GAD-7', 'Transtorno de Ansiedade Generalizada', '7', '0-21', 'Ansiedade (4 faixas: mínima a grave)'),
      _escala('DASS-21', 'Escala de Depressão, Ansiedade e Estresse', '21', '0-42/sub', '3 subescalas independentes'),

      // ============================================================
      // 7. TIPOS DE PDF
      // ============================================================
      espaco(16),
      pw.Text('7. Tipos de PDF (6)', style: tituloSecao(1)),
      espaco(10),

      _pdf('Registro de Sessão', 'Uma sessão: relato, síntese, formulação, intervenções, artigos, revisão'),
      _pdf('Histórico Clínico', 'Todas as sessões do paciente em cards compactos com data e relato'),
      _pdf('Relatório Clínico', 'Dados do paciente + evolução clínica (síntese de todas as sessões)'),
      _pdf('Síntese Revisada', 'Sessão única focada no conteúdo revisado pelo profissional'),
      _pdf('Prontuário Completo', 'Dossiê completo: todas as sessões com seções clínicas integrais'),
      _pdf('Relatório Financeiro', 'Mensal: KPIs + lista de sessões com valores e status de pagamento'),

      // ============================================================
      // 8. SEGURANÇA
      // ============================================================
      pw.NewPage(),
      pw.Text('8. Segurança e Criptografia', style: tituloSecao(1)),
      espaco(10),
      pw.Bullet(text: 'Criptografia local: AES-256-GCM com IV aleatório por registro (prefixo 3:)'),
      pw.Bullet(text: 'Derivação de chave: PBKDF2-HMAC-SHA256 com 100.000 iterações'),
      pw.Bullet(text: 'PIN com lockout exponencial (5 tentativas, máx 1 hora)'),
      pw.Bullet(text: 'Recuperação de PIN via email com token criptografado'),
      pw.Bullet(text: '26 campos clínicos criptografados em repouso no Hive'),
      pw.Bullet(text: 'JWT criptografado no Hive (EncryptionService.tryEncrypt)'),
      pw.Bullet(text: 'Senha do backend criptografada no app_config'),
      pw.Bullet(text: 'Áudio .m4a criptografado no disco'),
      pw.Bullet(text: 'Backup exige PIN antes de exportar'),
      pw.Bullet(text: 'Cascade delete: exclusão de paciente remove 8 boxes relacionados'),
      pw.Bullet(text: 'Auditoria LGPD com descrições criptografadas e trim a 1000 registros'),
      pw.Bullet(text: 'Android: allowBackup=false, cleartextTraffic=false, networkSecurityConfig'),

      // ============================================================
      // 9. STACK TÉCNICA
      // ============================================================
      espaco(16),
      pw.Text('9. Stack Técnica', style: tituloSecao(1)),
      espaco(10),

      pw.Text('Frontend (Flutter)', style: tituloSecao(2)),
      pw.Bullet(text: 'Flutter SDK ^3.12.2, Dart, Riverpod (estado 100%), Hive CE (banco local)'),
      pw.Bullet(text: 'Áudio: record + audioplayers + path_provider'),
      pw.Bullet(text: 'Geração de código: build_runner + hive_ce_generator'),
      pw.Bullet(text: 'PDF: pdf + printing, Imagem: image_picker'),
      pw.Bullet(text: 'Notificações: flutter_local_notifications, SMS/WhatsApp: Twilio'),
      pw.Bullet(text: 'Segurança: encrypt + pointycastle + flutter_secure_storage + local_auth'),
      pw.Bullet(text: 'Rede: http + share_plus + file_picker + url_launcher'),
      espaco(8),

      pw.Text('Backend (Python FastAPI)', style: tituloSecao(2)),
      pw.Bullet(text: 'FastAPI + Uvicorn, Pydantic v2, python-jose (JWT), passlib (bcrypt)'),
      pw.Bullet(text: 'IA: OpenAI GPT-4.1/GPT-4o-mini, DeepSeek V4 Flash, Google Gemini 2.0 Flash'),
      pw.Bullet(text: 'Transcrição: Groq Whisper large-v3-turbo, OpenAI gpt-4o-mini-transcribe'),
      pw.Bullet(text: 'Artigo: OpenAlex API com rerank pela IA'),
      pw.Bullet(text: 'Banco: Turso (libsql) com fallback SQLite local'),
      pw.Bullet(text: 'Mensageria: Twilio (SMS + WhatsApp), SMTP (email)'),
      pw.Bullet(text: 'Deploy: Render.com (plano gratuito, cold start ~30-60s)'),
      espaco(8),

      pw.Text('APK', style: tituloSecao(2)),
      pw.Bullet(text: 'Release: ~72.6MB, Android 7.0+, permissões: INTERNET, RECORD_AUDIO'),
      pw.Bullet(text: 'R8 + shrinkResources ativos, ProGuard configurado'),
    ],
  ));

  final file = File('docs/catalogo_funcionalidades_mentall_pro.pdf');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(await pdf.save());
  print('PDF gerado: ${file.absolute.path}');
  print('Tamanho: ${(await file.length() / 1024).toStringAsFixed(0)} KB');
}

// ============================================================
// Helpers
// ============================================================

const _bodyStyle = pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF334155));

pw.Widget _tela(dynamic doc, String nome, String desc, List<String> features) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 6),
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: const PdfColor.fromInt(0xFFF8FAFC),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Text(nome, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1E293B))),
            pw.SizedBox(width: 8),
            pw.Text('— $desc', style: pw.TextStyle(fontSize: 10, color: const PdfColor.fromInt(0xFF64748B))),
          ],
        ),
        if (features.isNotEmpty) pw.SizedBox(height: 4),
        for (final f in features) pw.Bullet(text: f, style: _bodyStyle),
      ],
    ),
  );
}

pw.Widget _servico(String nome, String desc) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(text: '$nome', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1E293B))),
          pw.TextSpan(text: ' — $desc', style: _bodyStyle),
        ],
      ),
    ),
  );
}

pw.Widget _widget(String nome, String desc) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(text: '$nome', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF2066FF))),
          pw.TextSpan(text: ' — $desc', style: _bodyStyle),
        ],
      ),
    ),
  );
}

pw.Widget _endpoint(String method, String path, String desc, bool auth) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(text: '$method ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF2066FF))),
          pw.TextSpan(text: path, style: pw.TextStyle(fontSize: 9, color: const PdfColor.fromInt(0xFF1E293B))),
          pw.TextSpan(text: ' ${auth ? "🔒" : "🌐"} ', style: const pw.TextStyle(fontSize: 9)),
          pw.TextSpan(text: '— $desc', style: pw.TextStyle(fontSize: 9, color: const PdfColor.fromInt(0xFF64748B))),
        ],
      ),
    ),
  );
}

pw.Widget _escala(String nome, String desc, String questoes, String score, String interpretacao) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 4),
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      color: const PdfColor.fromInt(0xFFF8FAFC),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Text(nome, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1E293B))),
            pw.SizedBox(width: 8),
            pw.Text('$questoes questões, score $score', style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF64748B))),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.Text('$desc — $interpretacao', style: _bodyStyle),
      ],
    ),
  );
}

pw.Widget _pdf(String nome, String desc) {
  return pw.Bullet(
    text: '$nome: $desc',
    style: _bodyStyle,
  );
}
