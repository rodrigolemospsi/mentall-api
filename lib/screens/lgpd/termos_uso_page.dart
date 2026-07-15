import 'package:flutter/material.dart';

class TermosUsoPage extends StatelessWidget {
  const TermosUsoPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color corPrincipal = Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Termos de Uso'),
        backgroundColor: corPrincipal,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _Termo(
            titulo: '1. Aceitacao dos Termos',
            texto:
                'Ao utilizar o MentAll, voce concorda com estes Termos de Uso. '
                'Se nao concordar, nao utilize o aplicativo.',
          ),
          _Termo(
            titulo: '2. Descricao do Servico',
            texto:
                'O MentAll e um aplicativo de prontuario psicologico inteligente '
                'que oferece:\n\n'
                '• Cadastro e gestao de pessoas atendidas.\n'
                '• Registro de sessoes clinicas.\n'
                '• Gravacao de relato pos-sessao em audio (limite de 5 minutos).\n'
                '• Transcricao automatica de audio (via OpenAI Whisper).\n'
                '• Sintese clinica com inteligencia artificial (via OpenAI GPT-4.1).\n'
                '• Apontamentos clinicos auxiliares gerados por IA.\n'
                '• Exportacao de documentos em PDF.\n'
                '• Backup e restauracao de dados.',
          ),
          _Termo(
            titulo: '3. Responsabilidade Profissional',
            texto:
                'O MentAll e uma ferramenta de apoio documental. A responsabilidade '
                'clinica e inteiramente do profissional de psicologia. A IA nao '
                'substitui o julgamento profissional, nao emite diagnosticos e nao '
                'toma decisoes terapeuticas. Todo conteudo gerado por IA deve ser '
                'revisado e validado pelo profissional antes de integrar o prontuario.',
          ),
          _Termo(
            titulo: '4. Uso do Audio',
            texto:
                'O recurso de audio destina-se exclusivamente ao registro breve '
                'do relato pos-sessao feito pelo profissional. A duracao maxima '
                'e de 5 minutos por registro. O profissional e responsavel por '
                'garantir que o audio nao contenha gravacao da sessao com a pessoa '
                'atendida, mas apenas seu proprio relato profissional apos o '
                'atendimento.',
          ),
          _Termo(
            titulo: '5. Dados e Privacidade',
            texto:
                'O tratamento de dados pessoais e clinicos pelo MentAll esta '
                'descrito na Politica de Privacidade, que e parte integrante '
                'destes Termos de Uso. O profissional e o controlador dos dados '
                'clinicos de suas pessoas atendidas.',
          ),
          _Termo(
            titulo: '6. Limitacao de Responsabilidade',
            texto:
                'O MentAll e fornecido "como esta", sem garantias expressas ou '
                'implicitas. O desenvolvedor nao se responsabiliza por:\n\n'
                '• Decisoes clinicas tomadas com base no conteudo gerado por IA.\n'
                '• Perda de dados por falha no dispositivo ou armazenamento.\n'
                '• Uso indevido do aplicativo pelo profissional.\n'
                '• Consequencias do compartilhamento de credenciais de acesso.',
          ),
          _Termo(
            titulo: '7. Licenca de Uso',
            texto:
                'O MentAll concede ao profissional uma licenca limitada, nao '
                'exclusiva e nao transferivel para uso do aplicativo conforme '
                'sua finalidade. E proibido:\n\n'
                '• Copiar, modificar ou distribuir o aplicativo.\n'
                '• Realizar engenharia reversa.\n'
                '• Utilizar o aplicativo para fins ilicitos.',
          ),
          _Termo(
            titulo: '8. Modificacoes dos Termos',
            texto:
                'Estes Termos de Uso poderao ser atualizados periodicamente. '
                'O uso continuado do aplicativo apos alteracoes constitui '
                'aceitacao dos novos termos.',
          ),
          _Termo(
            titulo: '9. Disposicoes Gerais',
            texto:
                'Estes Termos de Uso sao regidos pelas leis brasileiras. '
                'Qualquer disputa sera resolvida no foro da comarca do '
                'desenvolvedor.\n\n'
                'Ultima atualizacao: Julho de 2026.',
          ),
          SizedBox(height: 40),
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
