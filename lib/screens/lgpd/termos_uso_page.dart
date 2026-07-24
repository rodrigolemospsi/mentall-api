import 'package:flutter/material.dart';

class TermosUsoPage extends StatelessWidget {
  const TermosUsoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Termos de Uso'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Termo(
            titulo: '1. Aceitação dos Termos',
            texto:
                'Ao utilizar o MentAll, você concorda com estes Termos de Uso. '
                'Se não concordar, não utilize o aplicativo.',
          ),
          _Termo(
            titulo: '2. Descrição do Serviço',
            texto:
                'O MentAll é um aplicativo de prontuário psicológico inteligente '
                'que oferece:\n\n'
                '• Cadastro e gestão de pessoas atendidas.\n'
                '• Registro de sessões clínicas.\n'
                '• Gravação de relato pós-sessão em áudio (limite de 5 minutos).\n'
                '• Transcrição automática de áudio (via OpenAI Whisper).\n'
                '• Síntese clínica com inteligência artificial (via OpenAI GPT-4.1).\n'
                '• Apontamentos clínicos auxiliares gerados por IA.\n'
                '• Exportação de documentos em PDF.\n'
                '• Backup e restauração de dados.',
          ),
          _Termo(
            titulo: '3. Responsabilidade Profissional',
            texto:
                'O MentAll é uma ferramenta de apoio documental. A responsabilidade '
                'clínica é inteiramente do profissional de psicologia. A IA não '
                'substitui o julgamento profissional, não emite diagnósticos e não '
                'toma decisões terapêuticas. Todo conteúdo gerado por IA deve ser '
                'revisado e validado pelo profissional antes de integrar o prontuário.',
          ),
          _Termo(
            titulo: '4. Uso do Áudio',
            texto:
                'O recurso de áudio destina-se exclusivamente ao registro breve '
                'do relato pós-sessão feito pelo profissional. A duração máxima '
                'é de 5 minutos por registro. O profissional é responsável por '
                'garantir que o áudio não contenha gravação da sessão com a pessoa '
                'atendida, mas apenas seu próprio relato profissional após o '
                'atendimento.',
          ),
          _Termo(
            titulo: '5. Dados e Privacidade',
            texto:
                'O tratamento de dados pessoais e clínicos pelo MentAll está '
                'descrito na Política de Privacidade, que é parte integrante '
                'destes Termos de Uso. O profissional é o controlador dos dados '
                'clínicos de suas pessoas atendidas.',
          ),
          _Termo(
            titulo: '6. Limitação de Responsabilidade',
            texto:
                'O MentAll é fornecido "como está", sem garantias expressas ou '
                'implícitas. O desenvolvedor não se responsabiliza por:\n\n'
                '• Decisões clínicas tomadas com base no conteúdo gerado por IA.\n'
                '• Perda de dados por falha no dispositivo ou armazenamento.\n'
                '• Uso indevido do aplicativo pelo profissional.\n'
                '• Consequências do compartilhamento de credenciais de acesso.',
          ),
          _Termo(
            titulo: '7. Licença de Uso',
            texto:
                'O MentAll concede ao profissional uma licença limitada, não '
                'exclusiva e não transferível para uso do aplicativo conforme '
                'sua finalidade. É proibido:\n\n'
                '• Copiar, modificar ou distribuir o aplicativo.\n'
                '• Realizar engenharia reversa.\n'
                '• Utilizar o aplicativo para fins ilícitos.',
          ),
          _Termo(
            titulo: '8. Modificações dos Termos',
            texto:
                'Estes Termos de Uso poderão ser atualizados periodicamente. '
                'O uso continuado do aplicativo após alterações constitui '
                'aceitação dos novos termos.',
          ),
          _Termo(
            titulo: '9. Disposições Gerais',
            texto:
                'Estes Termos de Uso são regidos pelas leis brasileiras. '
                'Qualquer disputa será resolvida no foro da comarca do '
                'desenvolvedor.\n\n'
                'Última atualização: Julho de 2026.',
          ),
          const SizedBox(height: 40),
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
