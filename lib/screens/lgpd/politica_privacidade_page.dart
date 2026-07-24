import 'package:flutter/material.dart';

class PoliticaPrivacidadePage extends StatelessWidget {
  const PoliticaPrivacidadePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Política de Privacidade'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Secao(
            titulo: '1. Introdução',
            texto:
                'O MentAll é um aplicativo de prontuário psicológico inteligente, '
                'desenvolvido para apoiar psicólogos clínicos na documentação de '
                'atendimentos. Esta Política de Privacidade descreve como tratamos '
                'os dados pessoais e clínicos no uso do aplicativo.',
          ),
          _Secao(
            titulo: '2. Dados Coletados',
            texto:
                'O MentAll coleta apenas os dados necessários para o funcionamento '
                'do prontuário clínico:\n\n'
                '• Dados do profissional: nome, registro profissional, abordagem '
                'clínica, preferências de termo.\n'
                '• Dados da pessoa atendida: nome, data de nascimento, contato, '
                'e-mail, observações.\n'
                '• Dados clínicos: relatos de sessão, áudio do relato pós-sessão, '
                'transcrições, sínteses geradas por IA, apontamentos clínicos.\n'
                '• Dados técnicos: status de processamento, erros técnicos, datas '
                'de criação e atualização.',
          ),
          _Secao(
            titulo: '3. Finalidade do Tratamento',
            texto:
                'Todos os dados coletados têm finalidade exclusiva de:\n\n'
                '• Organização do prontuário clínico.\n'
                '• Registro de sessões e histórico de atendimentos.\n'
                '• Transcrição de áudio para apoio documental.\n'
                '• Geração de síntese clínica com IA como ferramenta auxiliar.\n'
                '• Revisão profissional obrigatória do conteúdo.\n'
                '• Exportação de documentos para uso do profissional.',
          ),
          _Secao(
            titulo: '4. Armazenamento e Segurança',
            texto:
                'Os dados são armazenados localmente no dispositivo do profissional. '
                'O MentAll utiliza:\n\n'
                '• Criptografia AES-256 para proteção dos dados em repouso.\n'
                '• Bloqueio por PIN para controle de acesso ao aplicativo.\n'
                '• Autenticação JWT para comunicação com serviços de IA.\n'
                '• Auditoria de eventos relevantes para fins de conformidade.\n\n'
                'Nenhum dado clínico é armazenado em servidores externos sem '
                'consentimento explícito do profissional. O envio de áudio para '
                'transcrição e de texto para síntese ocorre apenas mediante ação '
                'explícita do profissional e utiliza conexão segura (HTTPS).',
          ),
          _Secao(
            titulo: '5. Compartilhamento de Dados',
            texto:
                'O MentAll não compartilha dados com terceiros, exceto:\n\n'
                '• Serviços de IA (OpenAI ou Google Gemini) exclusivamente para '
                'processamento de transcrição e síntese, mediante ação do profissional.\n'
                '• Futuros serviços de nuvem e sincronização, apenas com consentimento '
                'explícito do profissional e mediante contrato de tratamento de dados.\n\n'
                'O profissional é o controlador dos dados clínicos. O MentAll atua '
                'como operador tecnológico.',
          ),
          _Secao(
            titulo: '6. Retenção e Exclusão',
            texto:
                'O MentAll adota a regra de arquivamento em vez de exclusão. '
                'Pessoas atendidas e sessões arquivadas permanecem preservadas no '
                'prontuário, podendo ser restauradas. A exclusão definitiva, quando '
                'disponível, será protegida por confirmação múltipla e registrada '
                'em auditoria.',
          ),
          _Secao(
            titulo: '7. Direitos do Titular',
            texto:
                'O profissional, como responsável pelo tratamento, deve atender '
                'às solicitações dos titulares dos dados (pessoas atendidas) '
                'conforme a LGPD, incluindo:\n\n'
                '• Acesso aos dados.\n'
                '• Correção de dados incompletos ou incorretos.\n'
                '• Exportação dos dados.\n'
                '• Informação sobre o tratamento realizado.',
          ),
          _Secao(
            titulo: '8. Uso de Inteligência Artificial',
            texto:
                'A IA do MentAll atua exclusivamente como apoio documental. '
                'Todo conteúdo gerado deve ser revisado e validado pelo profissional. '
                'A IA não toma decisões clínicas, não emite diagnósticos e não '
                'substitui o julgamento profissional. Os dados enviados para '
                'processamento por IA são utilizados apenas para a geração da '
                'resposta e não são armazenados pelos provedores de IA para '
                'treinamento de modelos (conforme políticas da OpenAI e Google).',
          ),
          _Secao(
            titulo: '9. Alterações nesta Política',
            texto:
                'Esta política poderá ser atualizada para refletir melhorias no '
                'aplicativo ou mudanças legais. O profissional será notificado '
                'sobre alterações significativas.',
          ),
          _Secao(
            titulo: '10. Contato',
            texto:
                'Para dúvidas sobre privacidade ou tratamento de dados, entre em '
                'contato com o desenvolvedor do MentAll.\n\n'
                'Última atualização: Julho de 2026.',
          ),
          const SizedBox(height: 40),
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
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            texto,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
