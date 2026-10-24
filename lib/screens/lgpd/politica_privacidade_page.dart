import 'package:flutter/material.dart';

import '../../utils/links_legais.dart';
import '../../utils/mentall_colors.dart';
import '../../utils/tipografia.dart';

/// Política de Privacidade exibida no app (versão 1.2 — 23/10/2026).
///
/// O texto é um resumo fiel da versão publicada em [LinksLegais.privacidade],
/// que é a versão oficial. O botão "Ler no site" abre a página pública; o
/// conteúdo offline continua disponível para o profissional sem internet.
class PoliticaPrivacidadePage extends StatelessWidget {
  const PoliticaPrivacidadePage({super.key});

  Future<void> _abrirNoSite(BuildContext context) async {
    final abriu = await LinksLegais.abrir(LinksLegais.privacidade);
    if (!abriu && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível abrir o site. Verifique sua conexão e tente novamente.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.corFundo,
      appBar: AppBar(
        title: const Text('Política de Privacidade'),
        backgroundColor: context.corPrimaria,
        foregroundColor: context.corOnPrimaria,
        actions: [
          IconButton(
            tooltip: 'Ler a versão publicada no site',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _abrirNoSite(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _AvisoVersao(
            texto:
                'Versão ${LinksLegais.versaoPublicada}. A versão oficial é a publicada em '
                '${LinksLegais.privacidade}.',
            aoAbrirSite: () => _abrirNoSite(context),
          ),
          _Secao(
            titulo: '1. Quem somos e papéis',
            texto:
                'O MentAll PRO é um software de prontuário clínico para psicólogas e '
                'psicólogos. O profissional que usa o app é o controlador dos dados '
                'das pessoas que atende; o MentAll PRO atua como operador desses '
                'dados e como controlador dos dados da conta do profissional e da '
                'telemetria técnica (sem conteúdo clínico).\n\n'
                'O produto está em fase de lançamento e a empresa está em processo '
                'de constituição. Contato: contato@mentallpro.com.br.',
          ),
          _Secao(
            titulo: '2. Dados tratados',
            texto:
                '• Dados da conta: nome, registro profissional (CRP), abordagem '
                'clínica, preferências, e-mail e senha (armazenada apenas como hash).\n'
                '• Dados das pessoas atendidas: nome, data de nascimento, contato, '
                'e-mail, observações, tipo/modalidade de atendimento, dados '
                'financeiros e de agendamento.\n'
                '• Dados clínicos (sensíveis, art. 11 da LGPD): relatos, anotações, '
                'transcrições, sínteses e apontamentos com apoio de IA, anamnese, '
                'contrato terapêutico e histórico de sessões.\n'
                '• Áudio: somente o relato pós-sessão ditado pelo profissional '
                '(até 5 minutos). O app não se destina a gravar a sessão.\n'
                '• Dados técnicos: identificador de dispositivo, plataforma, versão, '
                'tipo de evento de uso, registros de erro e IP.\n\n'
                'Não coletamos localização, contatos, agenda do aparelho, fotos ou '
                'histórico de navegação. Não há anúncios nem rastreadores.',
          ),
          _Secao(
            titulo: '3. Finalidades e bases legais',
            texto:
                'Tratamos os dados para: registrar e organizar o prontuário; '
                'transcrever o relato em áudio; gerar síntese e evolução com apoio '
                'de IA; enviar anamnese e contrato; enviar lembretes de sessão; '
                'autenticar e manter a conta; medir uso e presença do app; '
                'segurança e prevenção a fraude; e cumprir obrigações legais.\n\n'
                'As bases legais incluem tutela da saúde, consentimento específico '
                '(quando aplicável), execução de contrato, legítimo interesse e '
                'cumprimento de obrigação legal. Não usamos dados clínicos para '
                'marketing, melhoria de produto ou treinamento de modelos.',
          ),
          _Secao(
            titulo: '4. Compartilhamento',
            texto:
                'O compartilhamento é limitado ao necessário e ocorre com os '
                'seguintes operadores/subprocessadores:\n\n'
                '• Fly.io (Brasil) — hospedagem do backend e do banco de dados do serviço.\n'
                '• Magalu Cloud (Brasil) — infraestrutura do site e do servidor de e-mail.\n'
                '• Cloudflare (EUA) — DNS e proteção de tráfego.\n'
                '• OpenAI (EUA) — síntese e apoio documental com IA.\n'
                '• Groq (EUA) — transcrição do áudio do relato.\n'
                '• Resend (EUA) — entrega de e-mails transacionais.\n'
                '• Mailu (auto-hospedado na Magalu Cloud) — caixas de e-mail do serviço.\n'
                '• Google Calendar — somente se o profissional conectar a própria '
                'conta; o app envia o resumo do evento, data/hora e sala, sem nome '
                'de paciente ou conteúdo clínico por padrão.',
          ),
          _Secao(
            titulo: '5. Transferência internacional',
            texto:
                'Alguns fornecedores processam dados fora do Brasil (por exemplo, '
                'OpenAI, Groq, Resend e Cloudflare, nos Estados Unidos). A '
                'transferência ocorre com base no consentimento específico e/ou em '
                'cláusulas contratuais de proteção de dados, conforme os arts. 33 a '
                '36 da LGPD.',
          ),
          _Secao(
            titulo: '6. Armazenamento e segurança',
            texto:
                '• No aparelho: o conteúdo clínico é protegido por criptografia '
                'AES-256-GCM em repouso; o app pode exigir biometria ou senha do '
                'dispositivo para abrir; o log técnico não contém conteúdo clínico.\n'
                '• No servidor: comunicação HTTPS/TLS, senha apenas como hash, '
                'acesso administrativo restrito com autenticação em duas etapas e '
                'auditoria das ações.\n'
                '• Backups: exportação cifrada com senha (PBKDF2 + AES-256-GCM), '
                'inclusive para troca de aparelho.\n\n'
                'O servidor armazena os dados operacionais do serviço (conta, '
                'contratos, respostas de anamnese, lembretes e telemetria). O '
                'prontuário clínico completo fica cifrado no aparelho do profissional.',
          ),
          _Secao(
            titulo: '7. Retenção e exclusão',
            texto:
                '• Dados da conta e do servidor: mantidos enquanto a conta estiver '
                'ativa e pelo prazo necessário ao cumprimento de obrigações legais. '
                'Quando o profissional pede a exclusão, os dados do servidor são '
                'eliminados.\n'
                '• Prontuário clínico: permanece cifrado no aparelho do profissional; '
                'o servidor não armazena o conteúdo clínico do prontuário. A guarda '
                'do prontuário é responsabilidade legal do profissional, pelos '
                'prazos previstos na legislação aplicável.\n'
                '• Backups e PDFs exportados: guardados pelo próprio profissional, '
                'que deve armazená-los com segurança.\n\n'
                'A exclusão da conta pode ser feita no app (Configurações → Conta → '
                'Excluir minha conta) ou pelo site: ${LinksLegais.exclusaoConta}.',
          ),
          _Secao(
            titulo: '8. Direitos do titular',
            texto:
                'Nos termos do art. 18 da LGPD, o titular pode solicitar: confirmação '
                'de tratamento e acesso; correção; anonimização, bloqueio ou '
                'eliminação de dados desnecessários; portabilidade e informação '
                'sobre compartilhamento; informação sobre a possibilidade de não '
                'consentir; e revogação do consentimento.\n\n'
                'Pedidos sobre dados clínicos devem ser feitos ao profissional '
                '(controlador). O MentAll PRO atende pedidos sobre conta e '
                'telemetria pelo canal do titular: contato@mentallpro.com.br. '
                'Prazo de resposta: até 15 dias.',
          ),
          _Secao(
            titulo: '9. Inteligência artificial',
            texto:
                'A IA atua exclusivamente como apoio documental: transcreve, organiza '
                'e sugere conteúdo. Todo conteúdo gerado deve ser revisado e validado '
                'pelo profissional. A IA não toma decisões clínicas, não emite '
                'diagnóstico e não substitui o julgamento profissional.\n\n'
                'No lançamento, a síntese usa apenas a OpenAI; a transcrição usa a '
                'Groq. Os dados enviados são usados somente para gerar a resposta e '
                'não são utilizados para treinar modelos.',
          ),
          _Secao(
            titulo: '10. Site, cookies e alterações',
            texto:
                'O site institucional é estático e não utiliza cookies próprios de '
                'análise, publicidade ou rastreamento. O aplicativo não exibe '
                'anúncios.\n\n'
                'Esta política pode ser atualizada para refletir mudanças no produto '
                'ou na legislação. A versão e a data oficiais estão no topo desta '
                'tela e na página publicada. Mudanças relevantes são comunicadas no '
                'aplicativo.',
          ),
          _Secao(
            titulo: '11. Contato',
            texto:
                'Canal do titular (LGPD): contato@mentallpro.com.br\n'
                'Suporte: suporte@mentallpro.com.br\n'
                'Site: ${LinksLegais.site}\n\n'
                'Versão ${LinksLegais.versaoPublicada}.',
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _AvisoVersao extends StatelessWidget {
  final String texto;
  final VoidCallback aoAbrirSite;

  const _AvisoVersao({required this.texto, required this.aoAbrirSite});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.corPrimaria.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.corPrimaria.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            texto,
            style: TextStyle(
              fontSize: Tipografia.sm,
              height: 1.4,
              color: context.corTextoSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: aoAbrirSite,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Ler a versão oficial no site'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Secao extends StatelessWidget {
  final String titulo;
  final String texto;

  const _Secao({required this.titulo, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontSize: Tipografia.md,
              fontWeight: FontWeight.bold,
              color: context.corPrimaria,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            texto,
            style: TextStyle(
              fontSize: Tipografia.base,
              height: 1.6,
              color: context.corTextoBody,
            ),
          ),
        ],
      ),
    );
  }
}
