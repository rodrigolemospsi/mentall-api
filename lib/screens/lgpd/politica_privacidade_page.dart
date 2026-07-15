import 'package:flutter/material.dart';

class PoliticaPrivacidadePage extends StatelessWidget {
  const PoliticaPrivacidadePage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color corPrincipal = Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Politica de Privacidade'),
        backgroundColor: corPrincipal,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _Secao(
            titulo: '1. Introducao',
            texto:
                'O MentAll e um aplicativo de prontuario psicologico inteligente, '
                'desenvolvido para apoiar psicologos clinicos na documentacao de '
                'atendimentos. Esta Politica de Privacidade descreve como tratamos '
                'os dados pessoais e clinicos no uso do aplicativo.',
          ),
          _Secao(
            titulo: '2. Dados Coletados',
            texto:
                'O MentAll coleta apenas os dados necessarios para o funcionamento '
                'do prontuario clinico:\n\n'
                '• Dados do profissional: nome, registro profissional, abordagem '
                'clinica, preferencias de termo.\n'
                '• Dados da pessoa atendida: nome, data de nascimento, contato, '
                'e-mail, observacoes.\n'
                '• Dados clinicos: relatos de sessao, audio do relato pos-sessao, '
                'transcricoes, sinteses geradas por IA, apontamentos clinicos.\n'
                '• Dados tecnicos: status de processamento, erros tecnicos, datas '
                'de criacao e atualizacao.',
          ),
          _Secao(
            titulo: '3. Finalidade do Tratamento',
            texto:
                'Todos os dados coletados tem finalidade exclusiva de:\n\n'
                '• Organizacao do prontuario clinico.\n'
                '• Registro de sessoes e historico de atendimentos.\n'
                '• Transcricao de audio para apoio documental.\n'
                '• Geracao de sintese clinica com IA como ferramenta auxiliar.\n'
                '• Revisao profissional obrigatoria do conteudo.\n'
                '• Exportacao de documentos para uso do profissional.',
          ),
          _Secao(
            titulo: '4. Armazenamento e Seguranca',
            texto:
                'Os dados sao armazenados localmente no dispositivo do profissional. '
                'O MentAll utiliza:\n\n'
                '• Criptografia AES-256 para protecao dos dados em repouso.\n'
                '• Bloqueio por PIN para controle de acesso ao aplicativo.\n'
                '• Autenticacao JWT para comunicacao com servicos de IA.\n'
                '• Auditoria de eventos relevantes para fins de conformidade.\n\n'
                'Nenhum dado clinico e armazenado em servidores externos sem '
                'consentimento explicito do profissional. O envio de audio para '
                'transcricao e de texto para sintese ocorre apenas mediante acao '
                'explicita do profissional e utiliza conexao segura (HTTPS).',
          ),
          _Secao(
            titulo: '5. Compartilhamento de Dados',
            texto:
                'O MentAll nao compartilha dados com terceiros, exceto:\n\n'
                '• Servicos de IA (OpenAI ou Google Gemini) exclusivamente para '
                'processamento de transcricao e sintese, mediante acao do profissional.\n'
                '• Futuros servicos de nuvem e sincronizacao, apenas com consentimento '
                'explicito do profissional e mediante contrato de tratamento de dados.\n\n'
                'O profissional e o controlador dos dados clinicos. O MentAll atua '
                'como operador tecnologico.',
          ),
          _Secao(
            titulo: '6. Retencao e Exclusao',
            texto:
                'O MentAll adota a regra de arquivamento em vez de exclusao. '
                'Pessoas atendidas e sessoes arquivadas permanecem preservadas no '
                'prontuario, podendo ser restauradas. A exclusao definitiva, quando '
                'disponivel, sera protegida por confirmacao multipla e registrada '
                'em auditoria.',
          ),
          _Secao(
            titulo: '7. Direitos do Titular',
            texto:
                'O profissional, como responsavel pelo tratamento, deve atender '
                'as solicitacoes dos titulares dos dados (pessoas atendidas) '
                'conforme a LGPD, incluindo:\n\n'
                '• Acesso aos dados.\n'
                '• Correcao de dados incompletos ou incorretos.\n'
                '• Exportacao dos dados.\n'
                '• Informacao sobre o tratamento realizado.',
          ),
          _Secao(
            titulo: '8. Uso de Inteligencia Artificial',
            texto:
                'A IA do MentAll atua exclusivamente como apoio documental. '
                'Todo conteudo gerado deve ser revisado e validado pelo profissional. '
                'A IA nao toma decisoes clinicas, nao emite diagnosticos e nao '
                'substitui o julgamento profissional. Os dados enviados para '
                'processamento por IA sao utilizados apenas para a geracao da '
                'resposta e nao sao armazenados pelos provedores de IA para '
                'treinamento de modelos (conforme politicas da OpenAI e Google).',
          ),
          _Secao(
            titulo: '9. Alteracoes nesta Politica',
            texto:
                'Esta politica podera ser atualizada para refletir melhorias no '
                'aplicativo ou mudancas legais. O profissional sera notificado '
                'sobre alteracoes significativas.',
          ),
          _Secao(
            titulo: '10. Contato',
            texto:
                'Para duvidas sobre privacidade ou tratamento de dados, entre em '
                'contato com o desenvolvedor do MentAll.\n\n'
                'Ultima atualizacao: Julho de 2026.',
          ),
          SizedBox(height: 40),
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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            texto,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
