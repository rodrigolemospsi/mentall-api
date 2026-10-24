import 'package:flutter/material.dart';

import '../../utils/links_legais.dart';
import '../../utils/mentall_colors.dart';
import '../../utils/tipografia.dart';

/// Termos de Uso exibidos no app (versão 1.2 — 23/10/2026).
///
/// O texto é um resumo fiel da versão publicada em [LinksLegais.termos], que é
/// a versão oficial. O conteúdo offline continua disponível no app.
class TermosUsoPage extends StatelessWidget {
  const TermosUsoPage({super.key});

  Future<void> _abrirNoSite(BuildContext context) async {
    final abriu = await LinksLegais.abrir(LinksLegais.termos);
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
        title: const Text('Termos de Uso'),
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
                '${LinksLegais.termos}.',
            aoAbrirSite: () => _abrirNoSite(context),
          ),
          _Termo(
            titulo: '1. Aceitação dos Termos',
            texto:
                'Ao utilizar o MentAll PRO, você concorda com estes Termos de Uso e '
                'com a Política de Privacidade, que é parte integrante deste '
                'documento. Se não concordar, não utilize o aplicativo.\n\n'
                'O aceite é registrado com data e versão dos documentos aceitos.',
          ),
          _Termo(
            titulo: '2. Descrição do serviço',
            texto:
                'O MentAll PRO é um aplicativo de prontuário psicológico que oferece:\n\n'
                '• Cadastro e gestão de pessoas atendidas.\n'
                '• Registro de sessões clínicas.\n'
                '• Gravação do relato pós-sessão em áudio (limite de 5 minutos).\n'
                '• Transcrição automática do áudio (Groq).\n'
                '• Síntese clínica com inteligência artificial (OpenAI).\n'
                '• Apontamentos clínicos auxiliares gerados por IA, com revisão obrigatória.\n'
                '• Exportação de documentos em PDF.\n'
                '• Backup e restauração de dados.\n'
                '• Integração opcional com Google Calendar para sincronizar a agenda.\n\n'
                'O MentAll PRO é uma ferramenta de apoio documental. Não é serviço de '
                'saúde, não realiza atendimento, não emite diagnóstico e não substitui '
                'o julgamento clínico do profissional.',
          ),
          _Termo(
            titulo: '3. Quem pode usar',
            texto:
                'O aplicativo destina-se a psicólogas e psicólogos com registro '
                'profissional ativo (CRP) e a clínicas que atuem por meio de '
                'profissional habilitado. É vedado o uso por pessoa sem habilitação '
                'para o exercício profissional. O profissional deve manter a '
                'veracidade dos dados de cadastro e o registro profissional ativo.',
          ),
          _Termo(
            titulo: '4. Conta e segurança',
            texto:
                '• O acesso é pessoal e intransferível. Mantenha a confidencialidade '
                'da senha e do PIN do aparelho.\n'
                '• Use o aplicativo somente em aparelho cuja segurança você controla '
                'e mantenha biometria ou senha de bloqueio ativas.\n'
                '• Suspeita de acesso indevido deve ser comunicada imediatamente ao '
                'suporte, para bloqueio e providências.',
          ),
          _Termo(
            titulo: '5. Responsabilidade profissional',
            texto:
                'A responsabilidade clínica, ética e legal pelo atendimento e pelo '
                'conteúdo do prontuário é integralmente do profissional. O conteúdo '
                'gerado por IA deve ser revisado e validado antes de integrar o '
                'prontuário — o aplicativo exige a marcação de revisão antes de '
                'salvar conteúdo gerado por IA.\n\n'
                'O profissional é o controlador dos dados pessoais das pessoas que '
                'atende, nos termos da LGPD, e deve informar a pessoa atendida sobre '
                'o uso do aplicativo e obter o consentimento aplicável. O '
                'profissional também responde pela guarda e pelo sigilo do '
                'prontuário, inclusive das cópias exportadas em PDF e dos backups.',
          ),
          _Termo(
            titulo: '6. Uso da inteligência artificial',
            texto:
                'A IA atua exclusivamente como apoio documental: transcreve, organiza '
                'e sugere conteúdo. Ela não fornece diagnóstico, não define conduta e '
                'não substitui o julgamento clínico. As sugestões podem conter '
                'imprecisões e devem ser conferidas pelo profissional.\n\n'
                'Para gerar a transcrição e a síntese, o conteúdo estritamente '
                'necessário é enviado aos fornecedores descritos na Política de '
                'Privacidade. Nenhum dado clínico é usado para treinar modelos.',
          ),
          _Termo(
            titulo: '7. Conteúdo do profissional e propriedade intelectual',
            texto:
                'O conteúdo que o profissional insere (dados de pacientes, anotações, '
                'contratos, anamnese) é de responsabilidade e titularidade dele. O '
                'MentAll PRO não utiliza esse conteúdo para finalidade própria.\n\n'
                'O software, a marca, o layout e os materiais do MentAll PRO são '
                'protegidos por direitos de propriedade intelectual. É vedado copiar, '
                'modificar, distribuir ou fazer engenharia reversa do aplicativo, '
                'salvo autorização expressa ou previsão legal.',
          ),
          _Termo(
            titulo: '8. Dados e privacidade',
            texto:
                'O tratamento de dados pessoais e clínicos está descrito na Política '
                'de Privacidade, que é parte integrante destes Termos. O profissional '
                'é o controlador dos dados clínicos de suas pessoas atendidas.\n\n'
                'Canal do titular (LGPD): contato@mentallpro.com.br — resposta em até '
                '15 dias. Versão publicada: ${LinksLegais.privacidade}.',
          ),
          _Termo(
            titulo: '9. Comunicações',
            texto:
                'O MentAll PRO pode enviar comunicações operacionais (confirmação de '
                'cadastro, redefinição de senha, avisos de segurança). Lembretes de '
                'sessão por WhatsApp dependem de consentimento e da conexão do '
                'WhatsApp do próprio profissional.',
          ),
          _Termo(
            titulo: '10. Disponibilidade e condições comerciais',
            texto:
                'O serviço está em fase de lançamento e pode passar por manutenções e '
                'atualizações. O MentAll PRO envidará esforços para manter a '
                'disponibilidade, mas não garante funcionamento ininterrupto ou livre '
                'de erros. O prontuário permanece no aparelho do profissional, que '
                'deve manter backups exportados periodicamente.\n\n'
                'As condições comerciais (planos e eventuais cobranças) serão '
                'informadas no aplicativo e nas lojas antes de qualquer contratação.',
          ),
          _Termo(
            titulo: '11. Encerramento e exclusão',
            texto:
                'O profissional pode deixar de usar o aplicativo a qualquer momento e '
                'solicitar a exclusão da conta dentro do app (Configurações → Conta → '
                'Excluir minha conta) ou pela página ${LinksLegais.exclusaoConta}.\n\n'
                'A exclusão da conta apaga os dados do servidor; o prontuário cifrado '
                'permanece no aparelho, conforme a guarda legal aplicável. O MentAll '
                'PRO pode suspender ou encerrar contas em caso de uso indevido, fraude '
                'ou violação destes Termos.',
          ),
          _Termo(
            titulo: '12. Garantias e responsabilidade',
            texto:
                'O aplicativo é fornecido "como está", dentro do que a legislação '
                'permite. O MentAll PRO não responde por:\n\n'
                '• Decisões clínicas tomadas com base no conteúdo gerado por IA.\n'
                '• Conteúdo inserido pelo profissional.\n'
                '• Perda de dados decorrente de mau uso do aparelho ou falta de backup.\n'
                '• Cópias exportadas sem a devida proteção.\n\n'
                'Nada nestes Termos limita direitos do consumidor previstos em lei.',
          ),
          _Termo(
            titulo: '13. Modificações e foro',
            texto:
                'Estes Termos podem ser atualizados para refletir mudanças no produto '
                'ou na legislação. A versão e a data oficiais estão no topo desta tela '
                'e na página publicada; mudanças relevantes são comunicadas no '
                'aplicativo e, quando aplicável, exigem novo aceite.\n\n'
                'Estes Termos são regidos pelas leis brasileiras, em especial a LGPD '
                '(Lei nº 13.709/2018), o Marco Civil da Internet (Lei nº 12.965/2014) '
                'e o Código de Defesa do Consumidor, quando aplicável. Fica eleito o '
                'foro do domicílio do usuário para dirimir controvérsias, quando a '
                'legislação consumerista assim determinar.',
          ),
          _Termo(
            titulo: '14. Contato',
            texto:
                'Contato: contato@mentallpro.com.br\n'
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

class _Termo extends StatelessWidget {
  final String titulo;
  final String texto;

  const _Termo({required this.titulo, required this.texto});

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
