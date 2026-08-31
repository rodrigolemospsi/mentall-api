// ignore_for_file: avoid_print

import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const violeta = PdfColor.fromInt(0xFF8806CE);
const violetaClaro = PdfColor.fromInt(0xFFA10AF5);
const violetaEscuro = PdfColor.fromInt(0xFF52047C);
const marca = PdfColor.fromInt(0xFFC77DFF);
const grafite = PdfColor.fromInt(0xFF2F2F2F);
const heading = PdfColor.fromInt(0xFF1E293B);
const body = PdfColor.fromInt(0xFF334155);
const secundaria = PdfColor.fromInt(0xFF475569);
const muted = PdfColor.fromInt(0xFF64748B);
const verdeStatus = PdfColor.fromInt(0xFF2E7D32);
const laranjaPendente = PdfColor.fromInt(0xFFE65100);
const azulScheduled = PdfColor.fromInt(0xFF1976D2);
const fog = PdfColor.fromInt(0xFFF5F5F5);
const bg = PdfColor.fromInt(0xFFF8FAFC);
const surface = PdfColor.fromInt(0xFFF1F5F9);
const linha = PdfColor.fromInt(0xFFE2E8F0);
const branco = PdfColor.fromInt(0xFFFFFFFF);

pw.Widget espaco([double h = 6]) => pw.SizedBox(height: h);

Future<void> main() async {
  final pdf = pw.Document(
    title: 'Prompt do Site Institucional - MentAll PRO',
    author: 'MentAll PRO',
  );

  final logoClaro = pw.MemoryImage((await File('assets/images/logo_mentallpro_fundoclaro_01.png').readAsBytes()));
  final logoSemNome = pw.MemoryImage((await File('assets/images/logo_mentallpro_sem_nome_01.png').readAsBytes()));

  pw.TextStyle tituloSecao(int nivel) => pw.TextStyle(
        fontSize: nivel == 1 ? 20 : nivel == 2 ? 15 : 12,
        fontWeight: nivel <= 2 ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: nivel == 1 ? violeta : nivel == 2 ? heading : body,
      );

  pw.Widget cabecalho() => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: linha, width: 0.5),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Row(
              children: [
                pw.Image(logoSemNome, width: 22, height: 22),
                pw.SizedBox(width: 6),
                pw.Text('MentAll PRO', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: violeta)),
              ],
            ),
            pw.Text('Prompt Site Institucional', style: const pw.TextStyle(fontSize: 10, color: muted)),
          ],
        ),
      );

  pw.Widget tableHeader(List<String> cols) => pw.Container(
        decoration: const pw.BoxDecoration(
          color: violeta,
          borderRadius: pw.BorderRadius.only(topLeft: pw.Radius.circular(6), topRight: pw.Radius.circular(6)),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: pw.Row(
          children: [
            for (var i = 0; i < cols.length; i++)
              pw.Expanded(
                flex: i == 0 ? 3 : 2,
                child: pw.Text(cols[i], style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: branco)),
              ),
          ],
        ),
      );

  pw.Widget tableRow(List<String> cells, List<int> flexes) => pw.Container(
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: linha, width: 0.5)),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: pw.Row(
          children: [
            for (var i = 0; i < cells.length; i++)
              pw.Expanded(
                flex: flexes[i],
                child: pw.Text(cells[i], style: const pw.TextStyle(fontSize: 9, color: secundaria)),
              ),
          ],
        ),
      );

  pdf.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    header: (_) => cabecalho(),
    footer: (ctx) => pw.Center(
        child: pw.Text('Página ${ctx.pageNumber}  -  MentAll PRO - Prompt para Site Institucional', style: const pw.TextStyle(fontSize: 7, color: muted))),
    build: (ctx) => [
      // ============================================================
      // CAPA
      // ============================================================
      pw.Center(child: pw.Image(logoSemNome, width: 96, height: 96)),
      espaco(10),
      pw.Center(child: pw.Text('MentAll PRO', style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: violeta, letterSpacing: 2))),
      espaco(4),
      pw.Center(child: pw.Text('Prontuário Clínico com Inteligência Artificial', style: const pw.TextStyle(fontSize: 14, color: muted))),
      espaco(16),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
          border: pw.Border.all(color: violetaClaro, width: 0.5),
        ),
        child: pw.Column(
          children: [
            pw.Text('PROMPT COMPLETO PARA O SITE INSTITUCIONAL', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: violetaEscuro)),
            espaco(8),
            pw.Text(
              'Este documento é o style reference / prompt de geração para a construção do site institucional '
              'do MentAll PRO. Ele descreve o design system (cores, tipografia, formas, componentes), os assets '
              'de imagem (logos reais + mockups das telas do app), as funcionalidades/vantagens a serem usadas na '
              'copy, e o conjunto de tokens CSS/Tailwind pronto para uso. Base inspiradora: o sistema visual '
              '"Foodnoms - Style Reference", adaptado para a paleta violeta da marca MentAll PRO.',
              style: const pw.TextStyle(fontSize: 10, color: body, height: 1.5),
              textAlign: pw.TextAlign.justify,
            ),
          ],
        ),
      ),
      espaco(12),
      pw.Row(
        children: [
          pw.Expanded(child: _kpiMini('Tema', 'Light (claro)')),
          pw.SizedBox(width: 8),
          pw.Expanded(child: _kpiMini('Layout', '1 coluna centrada, max 1200px')),
          pw.SizedBox(width: 8),
          pw.Expanded(child: _kpiMini('Raio', '26px em tudo')),
          pw.SizedBox(width: 8),
          pw.Expanded(child: _kpiMini('Fonte', 'Nunito Sans')),
        ],
      ),

      pw.NewPage(),
      pw.Text('1. Visão Geral (Theme)', style: tituloSecao(1)),
      espaco(8),
      pw.Text(
        'O MentAll PRO apresenta uma linguagem de marketing de prontuário clínico "banhado pelo sol violeta": '
        'canvas branco puro, grandes mockups de celular como âncora visual, e um vocabulário cromático lúdico '
        'onde a cor codifica dados e progresso. A convenção de headline em dois tons (uma cor para a palavra de '
        'resultado, grafite escuro para o resto) torna a proposta de valor escaneável num relance. O sistema '
        'baseia-se numa única face display de leitura arredondada, de caráter geométrico, que amacia as telas '
        'densas do app. A maioria das superfícies é plana e sem sombra; um raio de canto uniforme de 26px dá a '
        'botões, cards e tags uma sensação amigável de "travesseiro", tornando o registro clínico acessível e '
        'acolhedor, nunca meramente técnico.',
        style: const pw.TextStyle(fontSize: 10, color: body, height: 1.5),
        textAlign: pw.TextAlign.justify,
      ),
      espaco(10),
      pw.Text('Tono da marca', style: tituloSecao(2)),
      espaco(4),
      pw.Bullet(text: 'Acolhedor, confiável e moderno - reduz a frieza do ambiente clínico/administrativo.'),
      pw.Bullet(text: 'Confiança profissional: segurança, LGPD, criptografia e conformidade em destaque, sem alarmismo.'),
      pw.Bullet(text: 'Empoderamento do psicólogo: autonomia, 14 abordagens, offline, IA de apoio (nunca substitui o julgamento clínico).'),
      pw.Bullet(text: 'A IA é apresentada como apoio documental - reforço ético e de credibilidade.'),
      espaco(6),
      pw.Text('Público-alvo', style: tituloSecao(2)),
      espaco(4),
      pw.Bullet(text: 'Psicólogos(as) clínicos(as) e psicoterapeutas no Brasil (CRP ativo).'),
      pw.Bullet(text: 'Profissionais de abordagens diversas: TCC, Psicanálise, ACT, DBT, Gestalt, Sistêmica e mais.'),
      pw.Bullet(text: 'Clínicas/consultórios individuais; foco também no onboarding de quem está iniciando.'),
      espaco(6),
      pw.Text('Dispositivo-foco', style: tituloSecao(2)),
      espaco(4),
      pw.Bullet(text: 'Android e iOS (telas de celular como âncora); desktop desktop-first no site (max-width 1200px).'),

      pw.NewPage(),
      pw.Text('2. Tokens - Cores', style: tituloSecao(1)),
      espaco(8),
      pw.Text(
        'Mapa de conversão a partir da referência Foodnoms: a ação/CTA/botão e a logo usam o violeta principal da '
        'marca; o acento de progresso/positivo usa o verde do app; o acento frio interno usa o azul de status '
        'agendado. Texto e superfícies seguem a paleta neutra do app.',
        style: const pw.TextStyle(fontSize: 10, color: body, height: 1.5),
        textAlign: pw.TextAlign.justify,
      ),
      espaco(10),
      tableHeader(['Nome', 'Valor', 'Papel']),
      tableRow(['Violeta Principal', '#8806CE', 'Ação de marca (botão cheio, logo, headings). NÃO usar como cor de dados'], [3, 2, 3]),
      tableRow(['Violeta Claro', '#A10AF5', 'Acento secundário em detalhes decorativos e destaques de baixa frequência'], [3, 2, 3]),
      tableRow(['Violeta Escuro', '#52047C', 'Tons profundos da marca - títulos máximos, splash, momentos escuros'], [3, 2, 3]),
      tableRow(['Lilás Marca', '#C77DFF', 'Acento de marca em legendas/cabeçalhos de documentos e detalhes suaves'], [3, 2, 3]),
      tableRow(['Verde Status', '#2E7D32', 'Acento de progresso/positivo (sessões realizadas, paciente ativo, sucesso)'], [3, 2, 3]),
      tableRow(['Laranja Pendente', '#E65100', 'Status pendente / revisão necessária - bom para badges de atenção'], [3, 2, 3]),
      tableRow(['Vermelho', '#D32F2F', 'Ação destrutiva, erro, falta - baixa frequência, alta atenção'], [3, 2, 3]),
      tableRow(['Azul Agendado', '#1976D2', 'Acento frio interno - status agendado/convênio, categorias de dados'], [3, 2, 3]),
      tableRow(['Teal Pacote', '#0D9488', 'Destaque de pacotes de sessões e dados positivos secundários'], [3, 2, 3]),
      tableRow(['Heading', '#1E293B', 'Título principal - texto de alto contraste em headings e copy'], [3, 2, 3]),
      tableRow(['Grafite', '#2F2F2F', 'Texto primário e botões escuros (badge da loja). Dominante não-branco'], [3, 2, 3]),
      tableRow(['Corpo', '#334155', 'Corpo de texto, parágrafos e descrições'], [3, 2, 3]),
      tableRow(['Secundária', '#475569', 'Texto secundário e labels de apoio'], [3, 2, 3]),
      tableRow(['Muted', '#64748B', 'Texto suave, legendas, placeholder'], [3, 2, 3]),
      tableRow(['Fog', '#F5F5F5', 'Canvas alternativo para cards, seções de feature e containers suaves'], [3, 2, 3]),
      tableRow(['Fundo Card', '#F8FAFC', 'Superfície de cards no app e no site'], [3, 2, 3]),
      tableRow(['Surface', '#F1F5F9', 'Superfície alternativa / trilhos e bandas'], [3, 2, 3]),
      tableRow(['Linha', '#E2E8F0', 'Divisores, bordas sutis'], [3, 2, 3]),
      tableRow(['Branco', '#FFFFFF', 'Fundo dominante da página, texto de botão, superfície de cards'], [3, 2, 3]),

      espaco(10),
      pw.Text('Convenção de uso', style: tituloSecao(3)),
      espaco(4),
      pw.Bullet(text: 'Cores cromáticas apenas sobre branco ou Fog. Nunca texto cromático sobre fundo cromático.'),
      pw.Bullet(text: 'Não chamar nenhuma cor de "CTA/primary action" - descrever pelo papel de marca (ex.: violeta de ação de marca).'),
      pw.Bullet(text: 'Sem gradientes: o sistema é cor sólida. A profundidade vem do contraste + raio 26px, não de sombras.'),

      pw.NewPage(),
      pw.Text('3. Tokens - Tipografia', style: tituloSecao(1)),
      espaco(8),
      pw.Text(
        'Substituta recomendada para a face custom da referência (redonda, geométrica, amigável): Nunito Sans. '
        'Pesos 700 (display/section) e 600 (subtítulos/botões) ancoram o sistema; peso 500 sustenta o corpo em '
        '17–20px com line-height generoso. Micro texto (12px e menores) usa system sans-serif.',
        style: const pw.TextStyle(fontSize: 10, color: body, height: 1.5),
        textAlign: pw.TextAlign.justify,
      ),
      espaco(10),
      tableHeader(['Papel', 'Tamanho', 'Line-height', 'Peso']),
      tableRow(['tiny', '12px', '1.2', 'System (fallback)'], [2, 2, 3, 3]),
      tableRow(['caption', '14px', '1.2', '600'], [2, 2, 3, 3]),
      tableRow(['body-sm', '16px', '1.4', '500'], [2, 2, 3, 3]),
      tableRow(['subheading', '20px', '1.8', '500'], [2, 2, 3, 3]),
      tableRow(['heading-sm', '22px', '1.2', '700'], [2, 2, 3, 3]),
      tableRow(['heading', '30px', '1.2', '700'], [2, 2, 3, 3]),
      tableRow(['display', '60px', '1.2', '700'], [2, 2, 3, 3]),

      espaco(10),
      pw.Text('Regras', style: tituloSecao(3)),
      espaco(4),
      pw.Bullet(text: 'Headline display: 60px Bold para o hero; headings de seção: 30px Bold. Não interpolar tamanhos intermediários (recomendação original).'),
      pw.Bullet(text: 'Padrão two-tone: uma palavra de resultado em violeta (#8806CE), o restante em Grafite.'),
      pw.Bullet(text: 'Botões: Nunito Sans DemiBold (600) ~16px.'),
      pw.Bullet(text: 'Nunito Sans não usar abaixo de 12px - fallback system (ui-sans-serif, system-ui).'),

      espaco(8),
      pw.Text('Escala de espaçamento', style: tituloSecao(3)),
      espaco(4),
      tableHeader(['Token', 'Valor']),
      tableRow(['--spacing-8', '8px'], [3, 3]),
      tableRow(['--spacing-24', '24px'], [3, 3]),
      tableRow(['--spacing-32', '32px'], [3, 3]),
      tableRow(['--spacing-40', '40px'], [3, 3]),
      tableRow(['--spacing-48', '48px'], [3, 3]),
      tableRow(['--spacing-56', '56px'], [3, 3]),
      tableRow(['--spacing-64', '64px'], [3, 3]),
      tableRow(['--spacing-96', '96px (gap de seção)'], [3, 3]),

      espaco(8),
      pw.Text('Formas (Shapes)', style: tituloSecao(3)),
      espaco(4),
      pw.Bullet(text: 'Raio em todos os elementos interativos e cards: 26px.'),
      pw.Bullet(text: 'Layout: max-width 1200px; gap de seção 96px; padding de card 32px; gap de elemento 20px.'),

      pw.NewPage(),
      pw.Text('4. Componentes', style: tituloSecao(1)),
      espaco(8),
      _componente('Logo / Wordmark', 'Identidade no header e footer', [
        'Logomarca: quadro violeta (#8806CE) com a marca "MentAll PRO".',
        'Wordmark: "MentAll PRO" weight 700, ~18px, Grafite (#2F2F2F), à direita do ícone.',
        'Altura total do lockup ~32px.',
      ]),
      _componente('Botão Preenchido de Marca', 'Ação principal na barra de navegação', [
        'Fundo Violeta Principal (#8806CE), texto branco "Baixar o app" em DemiBold ~16px.',
        'Ícone de seta (->) após o label. Raio 26px, padding vertical ~12px, horizontal ~20px.',
        'Posicionado à extrema direita do header.',
      ]),
      _componente('Link Nav Fantasma', 'Itens de navegação secundária', [
        'Sem fundo, texto Grafite (#2F2F2F), weight 500, ~16–17px, sem underline.',
        'Estado ativo: Violeta Principal ou sublinhado discreto - definir com consistência.',
      ]),
      _componente('Badge da App Store', 'CTA de download no hero', [
        'Retângulo Grafite (#2F2F2F), raio ~26px, logo Apple + "Disponível na App Store" em branco, Nunito Sans.',
        '~56px de altura, centralizado abaixo do subheadline.',
      ]),
      _componente('Headline Display em Duas Cores', 'Título do hero', [
        '60px Nunito Sans Bold, line-height 1.2. Primeira frase (resultado) em Violeta (#8806CE), segunda em Grafite.',
        'Centralizado, max-width constrito para manter a divisão de cor legível.',
      ]),
      _componente('Heading de Acento de Seção', 'Títulos de feature sections', [
        '30px Bold. Padrão two-tone: palavra de ação em Violeta, resto em Grafite.',
        'Ex.: "Anote em Segundos" v1 / "Prontuário com IA" - sempre a palavra de resultado em violeta.',
      ]),
      _componente('Carrossel de Mockups de Celular', 'Showcase visual do app', [
        'Mockups iPhone (~280px de largura), levemente sobrepostos e rotacionados, sem card de fundo.',
        'Flutuam direto na página branca; contêm a UI real do app (status bar, nav, telas de conteúdo).',
        'No hero: 2–4 mockups que representam Home, Sessão com IA, Agenda, Financeiro (ver seção 5).',
      ]),
      _componente('Grade de Imprensa', 'Prova social / menções na mídia', [
        'Grade 2 linhas × 3 colunas de logos em tons de grafite, espaçadas com ~64px de coluna.',
        'Heading "Destaques" em Violeta (#8806CE) acima.',
      ]),
      _componente('Card de Download CTA', 'Banner promocional', [
        'Card branco com fundo Fog (#F5F5F5), raio 26px, padding ~32px.',
        'Headline ("Comece com o MentAll PRO hoje"), subtexto e botão cheio Violeta "Baixar" com seta.',
        'Fica no rodapé da página, acima das seções de feature.',
      ]),
      _componente('Card de Dados Interno', 'Painel de resumo (dentro dos mockups)', [
        'Card branco, raio 26px, divisores cinza claros.',
        'Métrica grande em bold na cor de status (Verde #2E7D32 positivo; Laranja/E65100 pendente), label secundário grafite ~12-14px.',
      ]),
      _componente('Anel de Categoria', 'Indicador circular de progresso', [
        'Anel mostrando progresso (Sessões hoje, Pacientes ativos, Receita, Pendente).',
        'Cores por categoria: Violeta, Verde Status, Azul Agendado, Teal Pacote.',
        'Traço ~8px, valor numérico centralizado em bold.',
      ]),
      _componente('Linha de Registro de Log', 'Item de lista de atividade recente', [
        'Fundo branco com linha divisória inferior em Fog.',
        'Esquerda: nome/evento em Grafite weight 500 ~17px + meta subtexto em cinza claro ~14px.',
        'Direita: ponto colorido indicando categoria, com valores na cor correspondente.',
      ]),
      _componente('Barra de Abas', 'Navegação inferior no app', [
        'Barra branca com 3 ícones (Início, Pacientes, Financeiro) separados por divisores finos.',
        'Aba ativa indicada pelo preenchimento/ícone em Violeta e um pequeno ponto indicador.',
      ]),
      _componente('Chip de Status', 'Badge de estado de sessão/paciente', [
        'Chip pill com raio 26px, cor de fundo leve e texto na cor de status.',
        'Ex.: "Ativo" verde, "Pendente" laranja, "Agendado" azul, "Pacote" teal.',
      ]),

      pw.NewPage(),
      pw.Text('5. Imagens - Logos e Mockups das Telas', style: tituloSecao(1)),
      espaco(8),
      pw.Text(
        'Nenhuma screenshot está disponível no repositório - apenas as logos reais da marca. O site deve usar as '
        'logos embutidas neste PDF e os mockups de celular abaixo descritos por tela, de forma estilizada '
        '(browser-frame / device-frame), com a UI real do app como conteúdo.',
        style: const pw.TextStyle(fontSize: 10, color: body, height: 1.5),
        textAlign: pw.TextAlign.justify,
      ),
      espaco(10),

      pw.Text('5.1 Logos embutidas', style: tituloSecao(2)),
      espaco(6),
      pw.Row(
        children: [
          pw.Expanded(child: pw.Center(child: pw.Image(logoClaro, height: 70))),
          pw.Expanded(child: pw.Center(child: pw.Image(logoSemNome, height: 70))),
        ],
      ),
      espaco(4),
      pw.Bullet(text: 'logo_mentallpro_fundoclaro_01.png - para fundos claros (header/footer do site).'),
      pw.Bullet(text: 'logo_mentallpro_sem_nome_01.png - ícone/marca simplificada (favicon, wordmark sem o nome).'),
      espaco(8),

      pw.Text('5.2 Mockups das telas (descritos)', style: tituloSecao(2)),
      espaco(6),
      _mockup('Home / Dashboard', 'Dois-tons: saudação "Boa tarde, Dr./Dra. Nome" + ações rápidas (Novo paciente, Agendar, Nova sessão); grade de KPIs (Sessões hoje, Pacientes ativos, Receita, Pendente); feed de atividade recente.', violeta),
      _mockup('Sessão com IA', 'Formulário da sessão: gravação de áudio (5 min), botão transcrever, "Gerar síntese"; campos Relato, Síntese, Formulação, Intervenções, Apontamentos; card de artigos científicos sugeridos.', violetaClaro),
      _mockup('Agenda', 'Calendário nos modos Dia / Semana / Mês; compromissos com chip de status (Agendado azul, Realizado verde, Cancelado cinza, Faltou vermelho); botão "Novo compromisso" com recorrência e lembrete por WhatsApp.', azulScheduled),
      _mockup('Pacientes', 'Lista com busca, abas Ativos/Arquivados (com contadores); cards com avatar, nome, modalidade de atendimento e revisões pendentes.', laranjaPendente),
      _mockup('Financeiro', 'Seletor de mês/ano; KPIs Recebido, A receber, Convênio, Pacote, Total; lista de sessões com chips de pagamento (Pago verde, Pendente laranja, Convênio azul); botão exportar PDF financeiro.', verdeStatus),
      _mockup('Perfil / Configurações', 'Dados do profissional (nome, CRP verificado, foto), abordagem clínica (14 opções); Configurações com tema escuro, PIN, duração padrão e servidor.', marca),

      pw.NewPage(),
      pw.Text('6. Funcionalidades e Vantagens (copy do site)', style: tituloSecao(1)),
      espaco(8),
      pw.Text(
        'Use esta seção como base para os textos de vendas do site. Destaque os diferenciais reais do produto.',
        style: const pw.TextStyle(fontSize: 10, color: body, height: 1.5),
        textAlign: pw.TextAlign.justify,
      ),
      espaco(10),

      pw.Text('6.1 Pilares principais', style: tituloSecao(2)),
      espaco(4),
      _vantagem('14 abordagens terapêuticas', 'TCC, Psicanálise, ACT, DBT, Gestalt, Sistêmica e mais - o prontuário se adapta ao seu método, com labels de campos clínicos customizados.'),
      _vantagem('IA como apoio documental', 'Transcrição (~2s via Groq Whisper), síntese clínica e evolução automática. A IA organiza anotações e sugere artigos; a decisão é sempre sua (revisão obrigatória).'),
      _vantagem('Privacidade e LGPD', 'Criptografia AES-256-GCM em repouso, PIN com lockout, backup com senha, trilha de auditoria. Dados sensíveis de saúde protegidos por padrão.'),
      _vantagem('Offline nativo', 'Todo o prontuário fica no dispositivo (Hive CE); funciona sem internet e sincroniza quando quiser.'),
      _vantagem('3 escalas psicológicas gratuitas', 'PHQ-9 (depressão), GAD-7 (ansiedade) e DASS-21 - com scoring automático e interpretação; aplicação e reinformação em um toque.'),
      _vantagem('Agenda e lembretes por WhatsApp', 'Compromissos com recorrência (semanal/quinzenal/mensal), status e lembrete automático via WhatsApp do próprio profissional.'),
      _vantagem('Pacotes de sessões e controle financeiro', 'Crie pacotes, consuma FIFO, acompanhe recebimentos por mês e exporte relatório financeiro em PDF.'),
      _vantagem('Documentos em PDF com a sua marca', 'Registro de sessão, histórico clínico, relatório, síntese revisada, prontuário completo e relatório financeiro.'),
      _vantagem('Selo de verificação CRP', 'Verificação automática do registro via API do CFP, exibida como "Verificado" nos documentos.'),
      _vantagem('Flexível para o seu consultório', 'Modalidade online ou presencial, com endereços e busca de CEP; tratamento Dr./Dra. em todo o app.'),

      espaco(8),
      pw.Text('6.2 Estrutura de seções sugerida do site', style: tituloSecao(2)),
      espaco(4),
      pw.Bullet(text: 'Hero: headline two-tone + subheadline + badge da loja + mockups do app.'),
      pw.Bullet(text: 'Destaques de imprensa (logo grid).'),
      pw.Bullet(text: 'Recursos (features): alternar texto + mockup de celular, 3–5 blocos.'),
      pw.Bullet(text: 'Abordagens: 14 cards das metodologias suportadas.'),
      pw.Bullet(text: 'Segurança & LGPD: card destacando criptografia, auditoria e backup.'),
      pw.Bullet(text: 'Depoimentos / comparação: espaço para provas sociais.'),
      pw.Bullet(text: 'FAQ (perguntas frequentes).'),
      pw.Bullet(text: 'CTA final: card de download + acesso à política de privacidade e termos.'),
      pw.Bullet(text: 'Footer: logo, links (Home, Preços, Contato, Privacidade, Termos), nota LGPD.'),

      pw.NewPage(),
      pw.Text('7. Do\'s & Don\'ts', style: tituloSecao(1)),
      espaco(8),
      pw.Text('Do', style: tituloSecao(2)),
      espaco(4),
      pw.Bullet(text: 'Usar raio de borda de 26px em todos os elementos interativos e cards - é a suavidade assinatura do sistema.'),
      pw.Bullet(text: 'Aplicar o padrão de headline em duas cores: uma cor para a palavra de resultado, Grafite para o restante.'),
      pw.Bullet(text: 'Usar Nunito Sans Bold a 60px para display e 30px para headings de seção - não interpolar tamanhos intermediários.'),
      pw.Bullet(text: 'Associar Verde Status (#2E7D32) a dados positivos/progresso e Laranja/E65100 a pendências/atenção.'),
      pw.Bullet(text: 'Usar gaps de seção generosos (96px) para os mockups respirarem.'),
      pw.Bullet(text: 'Manter todo texto sobre branco ou Fog (#F5F5F5) - nunca texto cromático sobre fundo cromático.'),
      pw.Bullet(text: 'Mostrar 2–4 mockups lado a lado no hero, levemente sobrepostos, para demonstrar a amplitude do app.'),
      espaco(8),
      pw.Text('Don\'t', style: tituloSecao(2)),
      espaco(4),
      pw.Bullet(text: 'Não usar box-shadows / drop-shadows - o sistema é deliberadamente plano (profundidade via contraste + raio).'),
      pw.Bullet(text: 'Não usar outro raio que não 26px em botões, cards, tags ou inputs.'),
      pw.Bullet(text: 'Não chamar nenhuma cor de "CTA/primary action" no sistema de tokens - descrever pelo papel de marca.'),
      pw.Bullet(text: 'Não usar Nunito Sans abaixo de 12px - usar system sans-serif para micro UI.'),
      pw.Bullet(text: 'Não colocar texto cromático sobre fundo cromático - sempre combinar texto colorido com branco ou Fog.'),
      pw.Bullet(text: 'Não usar gradientes de fundo ou de botão - cor sólida apenas.'),
      pw.Bullet(text: 'Não introduzir novas cores cromáticas no site - a paleta violeta + acentos de status + dados está completa.'),

      pw.NewPage(),
      pw.Text('8. Superfícies e Elevação', style: tituloSecao(1)),
      espaco(8),
      tableHeader(['Nível', 'Nome', 'Valor', 'Função']),
      tableRow(['0', 'Paper White', '#FFFFFF', 'Canvas da página e superfície base'], [1, 2, 2, 4]),
      tableRow(['1', 'Fog', '#F5F5F5', 'Canvas alternativo p/ seções de feature e containers suaves'], [1, 2, 2, 4]),
      tableRow(['1', 'Fundo Card', '#F8FAFC', 'Superfície de cards do app e do site'], [1, 2, 2, 4]),
      tableRow(['2', 'Grafite', '#2F2F2F', 'Superfície invertida escura (badge da App Store)'], [1, 2, 2, 4]),
      tableRow(['3', 'Violeta', '#8806CE', 'Superfície preenchida de alta ênfase (botão do header)'], [1, 2, 2, 4]),
      espaco(10),
      pw.Text('Elevação', style: tituloSecao(2)),
      espaco(4),
      pw.Text(
        'O sistema é deliberadamente plano. Nenhuma sombra é usada em lugar algum - a profundidade é criada pelo '
        'contraste de cor e pelo raio de 26px em vez de drop shadows. Isso mantém a página leve, rápida e amigável.',
        style: const pw.TextStyle(fontSize: 10, color: body, height: 1.5),
        textAlign: pw.TextAlign.justify,
      ),
      espaco(10),

      pw.Text('9. Layout', style: tituloSecao(1)),
      espaco(8),
      pw.Text(
        'A página é uma única coluna, centralizada, com largura máxima de ~1200px e ritmo vertical generoso. '
        'O header é uma barra fina no topo: logo à esquerda, navegação no centro e botão de ação em violeta à '
        'direita. O hero é uma pilha centralizada: headline em duas cores, subheadline de uma linha, badge da '
        'loja e uma fileira de mockups de celular espalhados pela largura. Abaixo do hero, uma seção centralizada '
        'de logo de imprensa em grade 2×3. As seções de feature seguem um padrão repetitivo: duas colunas de '
        'texto + mockup de celular, alternando lados, com headings de acento em violeta/graffite. Antes do footer, '
        'um card de download CTA de largura total. Sem sidebar, sem mega-menu.',
        style: const pw.TextStyle(fontSize: 10, color: body, height: 1.5),
        textAlign: pw.TextAlign.justify,
      ),

      pw.NewPage(),
      pw.Text('10. Quick Reference - Tokens CSS / Tailwind', style: tituloSecao(1)),
      espaco(8),
      pw.Text(
        'Blocos prontos para copiar. O bloco 1 usa CSS custom properties (:root); o bloco 2 usa o diretório '
        '`@theme` do Tailwind v4.',
        style: const pw.TextStyle(fontSize: 10, color: body, height: 1.5),
        textAlign: pw.TextAlign.justify,
      ),
      espaco(10),
      _codigo("""
:root {
  /* Cores */
  --color-violeta-principal: #8806CE;
  --color-violeta-claro: #A10AF5;
  --color-violeta-escuro: #52047C;
  --color-lilas-marca: #C77DFF;
  --color-verde-status: #2E7D32;
  --color-laranja-pendente: #E65100;
  --color-vermelho: #D32F2F;
  --color-azul-scheduled: #1976D2;
  --color-teal-pacote: #0D9488;
  --color-heading: #1E293B;
  --color-grafite: #2F2F2F;
  --color-corpo: #334155;
  --color-secundaria: #475569;
  --color-muted: #64748B;
  --color-fog: #F5F5F5;
  --color-fundo-card: #F8FAFC;
  --color-surface: #F1F5F9;
  --color-linha: #E2E8F0;
  --color-paper-white: #FFFFFF;

  /* Tipografia */
  --font-nunito-sans: 'Nunito Sans', ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  --font-system-sans-serif: 'System sans-serif', ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;

  --text-tiny: 12px; --leading-tiny: 1.2;
  --text-caption: 14px; --leading-caption: 1.2;
  --text-body-sm: 16px; --leading-body-sm: 1.4;
  --text-subheading: 20px; --leading-subheading: 1.8;
  --text-heading-sm: 22px; --leading-heading-sm: 1.2;
  --text-heading: 30px; --leading-heading: 1.2;
  --text-display: 60px; --leading-display: 1.2;

  /* Espaçamento */
  --spacing-unit: 8px;
  --spacing-8: 8px; --spacing-24: 24px; --spacing-32: 32px; --spacing-40: 40px;
  --spacing-48: 48px; --spacing-56: 56px; --spacing-64: 64px; --spacing-96: 96px;

  /* Layout */
  --page-max-width: 1200px; --section-gap: 96px; --card-padding: 32px; --element-gap: 20px;

  /* Raio */
  --radius-tags: 26px; --radius-cards: 26px; --radius-inputs: 26px; --radius-buttons: 26px;
}
"""),
      _codigo("""
@theme {
  /* Cores */
  --color-violeta-principal: #8806CE;
  --color-violeta-claro: #A10AF5;
  --color-violeta-escuro: #52047C;
  --color-lilas-marca: #C77DFF;
  --color-verde-status: #2E7D32;
  --color-laranja-pendente: #E65100;
  --color-vermelho: #D32F2F;
  --color-azul-scheduled: #1976D2;
  --color-teal-pacote: #0D9488;
  --color-heading: #1E293B;
  --color-grafite: #2F2F2F;
  --color-corpo: #334155;
  --color-secundaria: #475569;
  --color-muted: #64748B;
  --color-fog: #F5F5F5;
  --color-fundo-card: #F8FAFC;
  --color-surface: #F1F5F9;
  --color-linha: #E2E8F0;
  --color-paper-white: #FFFFFF;

  /* Tipografia */
  --font-nunito-sans: 'Nunito Sans', ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  --font-system-sans-serif: 'System sans-serif', ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  --text-tiny: 12px; --leading-tiny: 1.2;
  --text-caption: 14px; --leading-caption: 1.2;
  --text-body-sm: 16px; --leading-body-sm: 1.4;
  --text-subheading: 20px; --leading-subheading: 1.8;
  --text-heading-sm: 22px; --leading-heading-sm: 1.2;
  --text-heading: 30px; --leading-heading: 1.2;
  --text-display: 60px; --leading-display: 1.2;
  --radius-3xl: 26px;
}
"""),

      pw.NewPage(),
      pw.Text('11. Prompts por Componente (exemplos prontos)', style: tituloSecao(1)),
      espaco(8),
      _prompt("""1. Seção Hero: fundo branco (#FFFFFF). Headline em duas cores a 60px Nunito Sans Bold, line-height 1.2: primeira frase em Violeta (#8806CE), segunda em Grafite (#2F2F2F), centralizada. Subtexto em Grafite Nunito Sans 500 17px, line-height 1.6. Badge Grafite da App Store abaixo (26px de raio, ~56px de altura). Fileira de 3-4 mockups de celular espalhada pela largura, mostrando Home, Sessão com IA, Agenda e Financeiro."""),
      _prompt("""2. Heading de Seção de Recurso: 30px Nunito Sans Bold, line-height 1.2: primeira palavra em Violeta (#8806CE), segunda em Grafite, alinhado à esquerda. Padding de 96px do topo em relação à seção anterior."""),
      _prompt("""3. Botão Preenchido de Marca: fundo Violeta (#8806CE), texto branco em Nunito Sans DemiBold 16px, line-height 1.2, raio 26px, padding vertical 12px, horizontal 20px, com um pequeno ícone de seta branco após o label."""),
      _prompt("""4. Grade de Logos de Imprensa: 2 linhas × 3 colunas de logos de publicações em tons de Grafite, 64px de gap de coluna, centralizado. Heading "Destaques" acima em Violeta (#8806CE) a 20px Nunito Sans 500."""),
      _prompt("""5. Card de Dados (dentro do mockup): card branco, raio 26px, divisores cinza claros. Métrica grande em bold na cor de status (Verde #2E7D32 = positivo, Laranja #E65100 = pendente) com label secundário em Grafite ~12-14px."""),
      _prompt("""6. Anel de Progresso: anel circular de progresso para cada indicador (Sessões hoje, Pacientes ativos, Receita, Pendente). Cor por categoria: Violeta, Verde Status, Azul Agendado, Teal Pacote. Traço ~8px, valor numérico centralizado em bold Nunito Sans."""),

      espaco(8),
      pw.Text('Estilo geral', style: tituloSecao(2)),
      espaco(4),
      pw.Bullet(text: 'Fundos planos, sem sombra. Contraste via cor sólida + raio 26px.'),
      pw.Bullet(text: 'Texto sempre sobre branco ou Fog; nunca texto cromático sobre fundo cromático.'),
      pw.Bullet(text: 'Sem gradientes; paleta cromática completa (violeta + acentos de status + dados).'),
      pw.Bullet(text: 'A identidade é carregada pela tipografia Nunito Sans, pelo sistema violeta/verde/grafite e pela própria UI do app, não por imagens de banco ou ilustrações abstratas.'),
    ],
  ));

  final file = File('docs/prompt_site_institucional_mentall_pro.pdf');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(await pdf.save());
  print('PDF gerado: ${file.absolute.path}');
  print('Tamanho: ${(await file.length() / 1024).toStringAsFixed(0)} KB');
}

// ============================================================
// Helpers
// ============================================================

pw.Widget _kpiMini(String label, String val) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: bg,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      border: pw.Border.all(color: linha, width: 0.5),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: muted, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5)),
        espaco(3),
        pw.Text(val, style: pw.TextStyle(fontSize: 9, color: body, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}

pw.Widget _componente(String nome, String desc, List<String> itens) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 8),
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: bg,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Text(nome, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: violeta)),
            pw.SizedBox(width: 8),
            pw.Text('- $desc', style: pw.TextStyle(fontSize: 10, color: muted, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        espaco(5),
        for (final t in itens) pw.Bullet(text: t, style: const pw.TextStyle(fontSize: 9.5, color: body, height: 1.4)),
      ],
    ),
  );
}

pw.Widget _mockup(String nome, String desc, PdfColor cor) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 8),
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: bg,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      border: pw.Border(left: pw.BorderSide(color: cor, width: 3)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: pw.BoxDecoration(color: cor, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20))),
              child: pw.Text(nome, style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: branco)),
            ),
            pw.SizedBox(width: 8),
            pw.Text('Mockup de celular', style: const pw.TextStyle(fontSize: 9, color: muted)),
          ],
        ),
        espaco(5),
        pw.Text(desc, style: const pw.TextStyle(fontSize: 9.5, color: body, height: 1.5)),
      ],
    ),
  );
}

pw.Widget _vantagem(String titulo, String texto) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 6),
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: bg,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(titulo, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: violetaEscuro)),
        espaco(2),
        pw.Text(texto, style: const pw.TextStyle(fontSize: 9.5, color: body, height: 1.5)),
      ],
    ),
  );
}

pw.Widget _codigo(String code) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 8),
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: const PdfColor.fromInt(0xFF0B1220),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
    ),
    child: pw.Text(
      code,
      style: pw.TextStyle(fontSize: 8, color: const PdfColor.fromInt(0xFFE2E8F0), fontWeight: pw.FontWeight.bold),
    ),
  );
}

pw.Widget _prompt(String texto) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 8),
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: surface,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      border: pw.Border.all(color: violetaClaro, width: 0.5),
    ),
    child: pw.Text(texto, style: const pw.TextStyle(fontSize: 9.5, color: body, height: 1.5)),
  );
}
