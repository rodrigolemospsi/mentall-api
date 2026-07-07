import '../models/enums.dart';

class ConfiguracaoAbordagemClinica {
  final String nomeAbordagem;

  final String tituloFormulaClinica;
  final String subtituloFormulaClinica;

  final String campo1Label;
  final String campo2Label;
  final String campo3Label;

  final String tituloIntervencoes;
  final String intervencoesLabel;
  final String tecnicasLabel;

  final String tituloPlano;
  final String tarefaLabel;
  final String planoLabel;

  final String eventosLabel;
  final String evolucaoLabel;
  final String apontamentosCopilotoLabel;

  const ConfiguracaoAbordagemClinica({
    required this.nomeAbordagem,
    required this.tituloFormulaClinica,
    required this.subtituloFormulaClinica,
    required this.campo1Label,
    required this.campo2Label,
    required this.campo3Label,
    required this.tituloIntervencoes,
    required this.intervencoesLabel,
    required this.tecnicasLabel,
    required this.tituloPlano,
    required this.tarefaLabel,
    required this.planoLabel,
    required this.eventosLabel,
    required this.evolucaoLabel,
    required this.apontamentosCopilotoLabel,
  });

  factory ConfiguracaoAbordagemClinica.porNome(String abordagem) {
    return ConfiguracaoAbordagemClinica._porEnum(
      AbordagemClinica.fromString(abordagem),
    );
  }

  factory ConfiguracaoAbordagemClinica._porEnum(AbordagemClinica abordagem) {
    switch (abordagem) {
      case AbordagemClinica.tcc:
        return const ConfiguracaoAbordagemClinica(
          nomeAbordagem: 'TCC',
          tituloFormulaClinica: 'Modelo cognitivo',
          subtituloFormulaClinica:
              'Campos inspirados no modelo cognitivo-comportamental para organizar pensamentos, emoções e comportamentos observados na sessão.',
          campo1Label: 'Pensamentos automáticos',
          campo2Label: 'Emoções',
          campo3Label: 'Comportamentos',
          tituloIntervencoes: 'Intervenções',
          intervencoesLabel: 'Intervenções realizadas',
          tecnicasLabel: 'Técnicas de TCC aplicadas',
          tituloPlano: 'Tarefas e plano',
          tarefaLabel: 'Tarefa de casa',
          planoLabel: 'Plano para próxima sessão',
          eventosLabel: 'Eventos importantes',
          evolucaoLabel: 'Evolução clínica',
          apontamentosCopilotoLabel:
              'Hipóteses funcionais, padrões e focos de atenção para revisão',
        );

      case AbordagemClinica.psicanalise:
        return const ConfiguracaoAbordagemClinica(
          nomeAbordagem: 'Psicanálise',
          tituloFormulaClinica: 'Dinâmica inconsciente',
          subtituloFormulaClinica:
              'Campos para registrar associações, transferência, resistências e movimentos inconscientes observados na sessão.',
          campo1Label: 'Associações, fantasias e conteúdos inconscientes',
          campo2Label: 'Afetos, angústias e vivências transferenciais',
          campo3Label: 'Resistências, atos e movimentos inconscientes',
          tituloIntervencoes: 'Intervenções e escuta analítica',
          intervencoesLabel: 'Intervenções realizadas',
          tecnicasLabel: 'Recursos da técnica analítica',
          tituloPlano: 'Processo e continuidade',
          tarefaLabel: 'Reflexão ou observação entre sessões',
          planoLabel: 'Foco analítico para a próxima sessão',
          eventosLabel: 'Eventos significativos',
          evolucaoLabel: 'Movimento do processo analítico',
          apontamentosCopilotoLabel:
              'Conflitos inconscientes, padrões transferenciais e resistências para revisão',
        );

      case AbordagemClinica.psicodinamica:
        return const ConfiguracaoAbordagemClinica(
          nomeAbordagem: 'Psicodinâmica',
          tituloFormulaClinica: 'Processo psicodinâmico',
          subtituloFormulaClinica:
              'Campos para organizar defesas, padrões relacionais, conflitos intrapsíquicos e a dinâmica da sessão.',
          campo1Label: 'Conteúdos, temas recorrentes e defesas',
          campo2Label: 'Afetos, conflitos e ansiedades',
          campo3Label: 'Padrões relacionais e transferência',
          tituloIntervencoes: 'Intervenções dinâmicas',
          intervencoesLabel: 'Intervenções realizadas',
          tecnicasLabel: 'Técnicas ou recursos dinâmicos utilizados',
          tituloPlano: 'Processo e continuidade',
          tarefaLabel: 'Reflexão ou observação entre sessões',
          planoLabel: 'Foco dinâmico para a próxima sessão',
          eventosLabel: 'Situações relevantes',
          evolucaoLabel: 'Mudanças na dinâmica psíquica',
          apontamentosCopilotoLabel:
              'Defesas, padrões e conflitos intrapsíquicos para revisão',
        );

      case AbordagemClinica.humanista:
        return const ConfiguracaoAbordagemClinica(
          nomeAbordagem: 'Humanista',
          tituloFormulaClinica: 'Experiência subjetiva',
          subtituloFormulaClinica:
              'Campos para registrar vivências, sentimentos, necessidades, autenticidade e processo de desenvolvimento pessoal.',
          campo1Label: 'Significados e necessidades percebidas',
          campo2Label: 'Sentimentos e vivências predominantes',
          campo3Label: 'Posturas, escolhas e movimentos pessoais',
          tituloIntervencoes: 'Facilitação terapêutica',
          intervencoesLabel: 'Intervenções, reflexões ou validações realizadas',
          tecnicasLabel: 'Recursos facilitadores utilizados',
          tituloPlano: 'Caminhos de desenvolvimento',
          tarefaLabel: 'Reflexão ou prática entre sessões',
          planoLabel: 'Foco de crescimento para a próxima sessão',
          eventosLabel: 'Vivências importantes',
          evolucaoLabel: 'Evolução subjetiva percebida',
          apontamentosCopilotoLabel:
              'Pontos de crescimento, autenticidade e congruência para revisão',
        );

      case AbordagemClinica.fenomenologicoExistencial:
        return const ConfiguracaoAbordagemClinica(
          nomeAbordagem: 'Fenomenológico-existencial',
          tituloFormulaClinica: 'Compreensão fenomenológico-existencial',
          subtituloFormulaClinica:
              'Campos para registrar modos de existir, sentidos, escolhas, angústias e possibilidades abertas na sessão.',
          campo1Label: 'Sentidos, temas e modos de compreender a experiência',
          campo2Label: 'Vivências, angústias e afetos existenciais',
          campo3Label: 'Escolhas, possibilidades e modos de estar-no-mundo',
          tituloIntervencoes: 'Intervenções e compreensão clínica',
          intervencoesLabel: 'Intervenções, devolutivas ou explorações feitas',
          tecnicasLabel: 'Recursos fenomenológicos ou existenciais utilizados',
          tituloPlano: 'Possibilidades e continuidade',
          tarefaLabel: 'Reflexão existencial entre sessões',
          planoLabel: 'Foco para a próxima sessão',
          eventosLabel: 'Experiências significativas',
          evolucaoLabel: 'Movimento existencial observado',
          apontamentosCopilotoLabel:
              'Possibilidades, sentidos e temas existenciais para revisão',
        );

      case AbordagemClinica.logoterapia:
        return const ConfiguracaoAbordagemClinica(
          nomeAbordagem: 'Logoterapia',
          tituloFormulaClinica: 'Compreensão clínica e sentido',
          subtituloFormulaClinica:
              'Campos para registrar temas de sentido, valores, posicionamentos e aspectos existenciais relevantes da sessão.',
          campo1Label: 'Pensamentos, valores e sentidos emergentes',
          campo2Label: 'Vivências emocionais e existenciais',
          campo3Label: 'Atitudes, escolhas e posicionamentos',
          tituloIntervencoes: 'Intervenções e recursos logoterapêuticos',
          intervencoesLabel: 'Intervenções realizadas',
          tecnicasLabel: 'Recursos logoterapêuticos utilizados',
          tituloPlano: 'Sentido, tarefa e próximo passo',
          tarefaLabel: 'Reflexão ou exercício para casa',
          planoLabel: 'Foco de sentido para a próxima sessão',
          eventosLabel: 'Eventos significativos',
          evolucaoLabel: 'Evolução no posicionamento e busca de sentido',
          apontamentosCopilotoLabel:
              'Valores, sentidos, atitudes e possibilidades para revisão',
        );

      case AbordagemClinica.gestaltTerapia:
        return const ConfiguracaoAbordagemClinica(
          nomeAbordagem: 'Gestalt-terapia',
          tituloFormulaClinica: 'Processo gestáltico',
          subtituloFormulaClinica:
              'Campos para registrar awareness, contato, interrupções, necessidades emergentes e movimentos no aqui-e-agora.',
          campo1Label: 'Temas, figuras e necessidades emergentes',
          campo2Label: 'Sensações, emoções e awareness',
          campo3Label: 'Contato, evitação e ajustamentos criativos',
          tituloIntervencoes: 'Experimentos e intervenções',
          intervencoesLabel: 'Intervenções realizadas',
          tecnicasLabel: 'Experimentos ou recursos gestálticos utilizados',
          tituloPlano: 'Integração e continuidade',
          tarefaLabel: 'Experimento ou observação entre sessões',
          planoLabel: 'Foco para a próxima sessão',
          eventosLabel: 'Experiências relevantes',
          evolucaoLabel: 'Movimento de awareness e integração',
          apontamentosCopilotoLabel:
              'Figuras, interrupções de contato e possibilidades para revisão',
        );

      case AbordagemClinica.sistemica:
        return const ConfiguracaoAbordagemClinica(
          nomeAbordagem: 'Sistêmica',
          tituloFormulaClinica: 'Formulação sistêmica',
          subtituloFormulaClinica:
              'Campos para organizar padrões relacionais, contexto familiar/social, comunicação e ciclos de interação.',
          campo1Label: 'Padrões relacionais e narrativas do sistema',
          campo2Label: 'Emoções e posições no sistema',
          campo3Label: 'Comunicação, papéis e ciclos de interação',
          tituloIntervencoes: 'Intervenções sistêmicas',
          intervencoesLabel: 'Intervenções realizadas',
          tecnicasLabel: 'Perguntas, recursos ou técnicas sistêmicas usadas',
          tituloPlano: 'Plano sistêmico',
          tarefaLabel: 'Tarefa ou observação relacional',
          planoLabel: 'Foco sistêmico para a próxima sessão',
          eventosLabel: 'Eventos contextuais relevantes',
          evolucaoLabel: 'Mudanças nos padrões relacionais',
          apontamentosCopilotoLabel:
              'Padrões sistêmicos, ciclos e hipóteses relacionais para revisão',
        );

      case AbordagemClinica.act:
        return const ConfiguracaoAbordagemClinica(
          nomeAbordagem: 'ACT',
          tituloFormulaClinica: 'Flexibilidade psicológica',
          subtituloFormulaClinica:
              'Campos para registrar experiências internas, esquiva, valores, ações comprometidas e processos de flexibilidade psicológica.',
          campo1Label: 'Pensamentos, fusão cognitiva e significados',
          campo2Label: 'Emoções, sensações e experiências internas',
          campo3Label: 'Esquiva, ações e comportamentos observados',
          tituloIntervencoes: 'Intervenções ACT',
          intervencoesLabel: 'Intervenções realizadas',
          tecnicasLabel: 'Processos ou exercícios ACT utilizados',
          tituloPlano: 'Valores e ação comprometida',
          tarefaLabel: 'Ação comprometida ou prática entre sessões',
          planoLabel: 'Foco de flexibilidade para a próxima sessão',
          eventosLabel: 'Situações relevantes',
          evolucaoLabel: 'Evolução em flexibilidade psicológica',
          apontamentosCopilotoLabel:
              'Valores, esquiva, fusão e ações comprometidas para revisão',
        );

      case AbordagemClinica.dbt:
        return const ConfiguracaoAbordagemClinica(
          nomeAbordagem: 'DBT',
          tituloFormulaClinica: 'Regulação emocional e habilidades',
          subtituloFormulaClinica:
              'Campos para registrar emoções, vulnerabilidades, comportamentos-alvo, habilidades utilizadas e análise da sessão.',
          campo1Label: 'Pensamentos, interpretações e vulnerabilidades',
          campo2Label: 'Emoções intensas e regulação emocional',
          campo3Label: 'Comportamentos-alvo e habilidades utilizadas',
          tituloIntervencoes: 'Intervenções DBT',
          intervencoesLabel: 'Intervenções realizadas',
          tecnicasLabel: 'Habilidades DBT trabalhadas',
          tituloPlano: 'Habilidades e plano',
          tarefaLabel: 'Prática de habilidade entre sessões',
          planoLabel: 'Plano para próxima sessão',
          eventosLabel: 'Eventos, crises ou gatilhos relevantes',
          evolucaoLabel: 'Evolução no uso de habilidades',
          apontamentosCopilotoLabel:
              'Comportamentos-alvo, habilidades e fatores de vulnerabilidade para revisão',
        );

      case AbordagemClinica.terapiaDoEsquema:
        return const ConfiguracaoAbordagemClinica(
          nomeAbordagem: 'Terapia do Esquema',
          tituloFormulaClinica: 'Esquemas, modos e necessidades emocionais',
          subtituloFormulaClinica:
              'Campos para registrar esquemas ativados, modos, necessidades emocionais e respostas de enfrentamento.',
          campo1Label: 'Esquemas, crenças e significados ativados',
          campo2Label: 'Emoções e necessidades emocionais',
          campo3Label: 'Modos, respostas de enfrentamento e comportamentos',
          tituloIntervencoes: 'Intervenções focadas em esquemas',
          intervencoesLabel: 'Intervenções realizadas',
          tecnicasLabel: 'Técnicas ou recursos da Terapia do Esquema',
          tituloPlano: 'Necessidades e continuidade',
          tarefaLabel: 'Exercício ou prática entre sessões',
          planoLabel: 'Foco para próxima sessão',
          eventosLabel: 'Situações ativadoras relevantes',
          evolucaoLabel: 'Evolução nos modos e respostas',
          apontamentosCopilotoLabel:
              'Esquemas, modos, necessidades e respostas para revisão',
        );

      case AbordagemClinica.integrativa:
      case AbordagemClinica.outra:
        return ConfiguracaoAbordagemClinica.integrativa();
    }
  }

  factory ConfiguracaoAbordagemClinica.integrativa() {
    return const ConfiguracaoAbordagemClinica(
      nomeAbordagem: 'Integrativa',
      tituloFormulaClinica: 'Formulação clínica',
      subtituloFormulaClinica:
          'Campos para organizar aspectos clínicos relevantes conforme a abordagem escolhida pelo profissional.',
      campo1Label: 'Pensamentos, significados ou temas relevantes',
      campo2Label: 'Emoções e vivências relevantes',
      campo3Label: 'Comportamentos, atitudes ou respostas observadas',
      tituloIntervencoes: 'Intervenções',
      intervencoesLabel: 'Intervenções realizadas',
      tecnicasLabel: 'Técnicas ou recursos clínicos utilizados',
      tituloPlano: 'Tarefas e plano',
      tarefaLabel: 'Tarefa, reflexão ou prática entre sessões',
      planoLabel: 'Plano para próxima sessão',
      eventosLabel: 'Eventos importantes',
      evolucaoLabel: 'Evolução clínica',
      apontamentosCopilotoLabel:
          'Hipóteses, padrões e focos de atenção para revisão',
    );
  }
}